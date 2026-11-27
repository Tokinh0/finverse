module Ai
  # Builds the compact JSON sent to Claude for one batch of merchant groups.
  #
  # Only what the decision needs goes out: the owner's subcategories, keyword rules, a few past
  # examples similar to the batch, and per merchant its scrubbed name, count, average amount,
  # type and statement kind. No ids beyond our own short item numbers, no dates, no totals.
  class PayloadBuilder
    MAX_EXAMPLES_PER_ITEM = 2
    MAX_EXAMPLES = 40
    EXAMPLE_SOURCES = %w[manual ai_accepted keyword].freeze
    # Tokens too common in bank descriptions to say anything about the merchant.
    GENERIC_TOKENS = %w[
      PAGAMENTO PAG PIX COMPRA COMPRAS DEBITO CREDITO TRANSFERENCIA TRANSF TED DOC RECEBIMENTO SAQUE
      CARTAO ENVIADO RECEBIDO LTDA EIRELI MEI SA ME DA DE DO DOS DAS E
    ].freeze

    # @param groups [Array<Suggestions::Candidates::Group>]
    # @param rejected [Hash{String => Array<Integer>}] rejected subcategory ids per merchant key
    def initialize(groups, rejected: {})
      @groups = groups
      @rejected = rejected
    end

    # @return [Hash] { payload:, items: { item_id => group } }
    def call
      items = groups.each_with_index.to_h { |group, index| [ index + 1, group ] }
      payload = {
        subcategories: subcategories,
        rules: Keyword.where(subcategory_id: allowed_subcategory_ids).order(:parsed_name).pluck(:parsed_name, :subcategory_id),
        examples: examples,
        items: items.map { |id, group| item(id, group) }
      }
      { payload: payload, items: items }
    end

    def allowed_subcategory_ids
      @allowed_subcategory_ids ||= Subcategory.where.not(id: Subcategory.other_subcategory.id).pluck(:id)
    end

    private

    attr_reader :groups, :rejected

    def subcategories
      Subcategory.includes(:category).where(id: allowed_subcategory_ids).order(:id).map do |subcategory|
        { id: subcategory.id, name: "#{subcategory.category.name} / #{subcategory.name}", type: subcategory.subcategory_type }
      end
    end

    def item(id, group)
      {
        id: id,
        name: Suggestions::Privacy.scrub(group.sample_name),
        count: group.transactions.size,
        avg_amount: group.average_amount,
        type: group.transaction_type,
        statement: group.statement_kinds.join(","),
        not: rejected.fetch(group.merchant_key, []).presence
      }.compact
    end

    # Past categorized transactions that share a meaningful word with a batch merchant,
    # owner decisions first. [scrubbed name, subcategory id] pairs, one per merchant.
    def examples
      wanted = groups.to_h { |group| [ group.merchant_key, tokens(group.merchant_key) ] }.reject { |_, t| t.empty? }
      return [] if wanted.empty?

      all_tokens = wanted.values.flatten.uniq
      candidates = Transaction.where(categorization_source: EXAMPLE_SOURCES)
                              .where(subcategory_id: allowed_subcategory_ids)
                              .where("parsed_name ~ ?", "(^|_)(#{all_tokens.map { Regexp.escape(_1) }.join('|')})(_|$)")
                              .order(Arel.sql("CASE categorization_source WHEN 'keyword' THEN 1 ELSE 0 END"), transaction_date: :desc)
                              .limit(500)
                              .select(:name, :parsed_name, :subcategory_id)

      seen = Set.new
      per_item = Hash.new(0)
      candidates.each_with_object([]) do |transaction, result|
        break result if result.size >= MAX_EXAMPLES

        key = Transactions::Merchant.key(transaction)
        next if seen.include?(key) || wanted.key?(key)

        owner = wanted.find { |item_key, item_tokens| per_item[item_key] < MAX_EXAMPLES_PER_ITEM && (tokens(key) & item_tokens).any? }&.first
        next unless owner

        seen << key
        per_item[owner] += 1
        result << [ Suggestions::Privacy.scrub(transaction.name), transaction.subcategory_id ]
      end
    end

    def tokens(merchant_key)
      merchant_key.split("_").select { _1.length >= 3 } - GENERIC_TOKENS
    end
  end
end
