module Ai
  # One Claude request for one batch of merchant groups. It asks for both a subcategory per
  # merchant and changes to the keyword rules, so an import costs a single call.
  # Returns validated suggestions plus token usage. Raises Ai::Client::Error on failure.
  class Suggester
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
      is better than a wrong one.

      Also propose a few high-value changes to the keyword rules in `rule_suggestions`, so future
      imports categorize more transactions on their own. A rule matches when its keyword appears
      inside the transaction name. Use:
      - `create` for a merchant pattern that recurs: an item with count > 1, a merchant in
        `corrections` (repeated manual choices by the owner, a strong signal), or several items
        sharing a distinctive word. Pick a distinctive part of the name, without numbers or
        generic words like PAGAMENTO, PIX or COMPRA. Set keyword_id to null.
      - `update` for a rule in `rule_issues` that the owner keeps overriding or that ties with
        another rule: give its keyword_id and the new keyword and/or subcategory_id.
      - `delete` for a rule that only causes wrong matches (keyword_id; keyword and
        subcategory_id null).
      `rule_issues` rows are [rule id, matches, overrides, subcategory the owner moved them to
      most, flags]. Never repeat a change in `rejected_rules`. An empty list is fine.

      `confidence` is your probability (0 to 1) that the owner agrees. `reason` is at most 12 words.
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
        },
        rule_suggestions: {
          type: "array",
          items: {
            type: "object",
            properties: {
              action: { type: "string", enum: %w[create update delete] },
              keyword_id: { type: %w[integer null] },
              keyword: { type: %w[string null] },
              subcategory_id: { type: %w[integer null] },
              confidence: { type: "number" },
              reason: { type: "string" }
            },
            required: %w[action keyword_id keyword subcategory_id confidence reason],
            additionalProperties: false
          }
        }
      },
      required: %w[category_suggestions rule_suggestions],
      additionalProperties: false
    }.freeze

    Result = Struct.new(:suggestions, :rule_suggestions, :dropped, :input_tokens, :output_tokens, keyword_init: true)
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
      validated = ResponseValidator.call(data, item_ids: built[:items].keys, subcategory_ids: builder.allowed_subcategory_ids,
                                               excluded: excluded, keyword_ids: Keyword.ids)
      Rails.logger.info("Claude suggestions: #{validated.category_suggestions.size} categories and " \
                        "#{validated.rule_suggestions.size} rules kept, #{validated.dropped} dropped")

      Result.new(
        suggestions: validated.category_suggestions.map do |s|
          Suggestion.new(group: built[:items].fetch(s[:item_id]), subcategory_id: s[:subcategory_id],
                         confidence: s[:confidence], reason: s[:reason])
        end,
        rule_suggestions: validated.rule_suggestions,
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
        raise Client::Error.new("refused", "Claude declined to answer for this batch.")
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
