module Ai
  # One Claude request for one batch of merchant groups. Returns validated suggestions keyed by
  # group, plus token usage. Raises Ai::Client::Error when the request or its answer fails.
  class CategorySuggester
    MAX_TOKENS = 16_000
    EFFORT = :low

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You categorize bank transactions for one person's personal finance app. The data is
      Brazilian (BRL, Portuguese descriptions). "#" in a name replaces a long number.

      For each entry in `items`, pick the subcategory id from `subcategories` that the owner would
      most likely choose. Follow the owner's conventions: `rules` are their keyword rules
      ([keyword, subcategory id]; keywords are upper case with spaces as "_") and `examples` are
      past transactions they categorized ([name, subcategory id]). `statement` says whether the
      item came from a credit card bill or a checking account; `type` is debit or credit.

      Never pick a subcategory listed in an item's `not`: the owner rejected it for that merchant.
      Leave an item out when you can't place it with reasonable confidence; a missing suggestion
      is better than a wrong one. `confidence` is your probability (0 to 1) that the owner agrees.
      `reason` is at most 12 words.
    PROMPT

    SCHEMA = {
      type: "object",
      properties: {
        category_suggestions: {
          type: "array",
          items: {
            type: "object",
            properties: {
              item_id: { type: "integer" },
              subcategory_id: { type: "integer" },
              confidence: { type: "number" },
              reason: { type: "string" }
            },
            required: %w[item_id subcategory_id confidence reason],
            additionalProperties: false
          }
        }
      },
      required: %w[category_suggestions],
      additionalProperties: false
    }.freeze

    Result = Struct.new(:suggestions, :dropped, :input_tokens, :output_tokens, keyword_init: true)
    Suggestion = Struct.new(:group, :subcategory_id, :confidence, :reason, keyword_init: true)

    def initialize(client)
      @client = client
    end

    # @param groups [Array<Suggestions::Candidates::Group>]
    # @param rejected [Hash{String => Array<Integer>}] rejected subcategory ids per merchant key
    def call(groups, rejected: {})
      builder = PayloadBuilder.new(groups, rejected: rejected)
      built = builder.call
      message = client.translate_errors { request(built[:payload]) }
      data = parse(message)

      excluded = built[:items].transform_values { rejected.fetch(_1.merchant_key, []) }
      validated = ResponseValidator.call(data, item_ids: built[:items].keys,
                                               subcategory_ids: builder.allowed_subcategory_ids, excluded: excluded)
      Rails.logger.info("Claude category suggestions: #{validated.category_suggestions.size} kept, #{validated.dropped} dropped")

      Result.new(
        suggestions: validated.category_suggestions.map do |s|
          Suggestion.new(group: built[:items].fetch(s[:item_id]), subcategory_id: s[:subcategory_id],
                         confidence: s[:confidence], reason: s[:reason])
        end,
        dropped: validated.dropped,
        input_tokens: message.usage.input_tokens.to_i,
        output_tokens: message.usage.output_tokens.to_i
      )
    end

    private

    attr_reader :client

    def request(payload)
      client.messages.create(
        model: client.model,
        max_tokens: MAX_TOKENS,
        system_: SYSTEM_PROMPT,
        output_config: { effort: EFFORT, format_: { type: :json_schema, schema: SCHEMA } },
        messages: [ { role: "user", content: payload.to_json } ]
      )
    end

    def parse(message)
      case message.stop_reason
      when :refusal
        raise Client::Error.new("refused", "Claude declined to categorize this batch.")
      when :max_tokens
        raise Client::Error.new("bad_response", "Claude's answer was cut off. Try again with fewer transactions.")
      end

      text = message.content.find { _1.type == :text }&.text
      JSON.parse(text.to_s)
    rescue JSON::ParserError
      raise Client::Error.new("bad_response", "Claude's answer wasn't valid JSON.")
    end
  end
end
