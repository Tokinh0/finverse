module Ai
  # Builds the compact JSON sent to Claude for one batch of merchant groups.
  #
  # Only what the decisions need goes out: the owner's subcategories, keyword rules (with stats
  # only for rules that have problems), a few past examples similar to the batch, repeated
  # manual corrections, recently rejected rule changes, and per merchant its scrubbed name,
  # count, average amount, type and statement kind. No dates, no totals, no account numbers.
  class PayloadBuilder
    MAX_EXAMPLES_PER_ITEM = 2
    MAX_EXAMPLES = 40
    MAX_CORRECTIONS = 30
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
        rules: Keyword.order(:parsed_name).pluck(:id, :parsed_name, :subcategory_id),
        rule_issues: rule_issues,
        examples: examples,
        corrections: corrections,
        rejected_rules: Rules::Rejections.recent,
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

    # [rule id, matches, overrides, subcategory the owner moved them to most, flags], only for
    # rules that are overridden or overlap. Unused rules are left out: they cost tokens and do
    # no harm.
    ISSUE_FLAGS = %w[overridden overlapping].freeze

    def rule_issues
      Rules::Health.call.values.filter_map do |entry|
        flags = entry.flags & ISSUE_FLAGS
        next if flags.empty?

        [ entry.keyword.id, entry.matches, entry.overrides, entry.top_override_subcategory_id, flags.join(",") ]
      end
    end

    # Merchants the owner put in the same subcategory by hand more than once:
    # [merchant, subcategory id, times]. A strong signal for a new rule.
    def corrections
      CategorizationEvent.where(to_source: %w[manual ai_accepted], to_subcategory_id: allowed_subcategory_ids)
                         .group(:merchant_key, :to_subcategory_id).having("COUNT(*) >= 2")
                         .order(Arel.sql("COUNT(*) DESC")).limit(MAX_CORRECTIONS).count
                         .map { |(key, subcategory_id), count| [ Suggestions::Privacy.scrub(key), subcategory_id, count ] }
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
