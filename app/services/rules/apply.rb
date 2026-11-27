module Rules
  # Applies a rule change and re-matches the transactions it touches.
  #
  # reapply:
  # - "none": only transactions the changed keyword categorized are re-matched (an updated or
  #   deleted rule must not keep claiming them).
  # - "uncategorized": also uncategorized transactions the new rules now match.
  # - "all": also transactions another keyword categorized, when the new rules match better.
  # Owner decisions (manual, ai_accepted) are never moved.
  class Apply
    REAPPLY = %w[none uncategorized all].freeze

    Result = Struct.new(:keyword, :updated_count, keyword_init: true)

    def self.call(change, reapply: "none")
      new(change, reapply).call
    end

    def initialize(change, reapply)
      raise ArgumentError, "reapply must be one of #{REAPPLY.join(', ')}" unless REAPPLY.include?(reapply.to_s)

      @change = change
      @reapply = reapply.to_s
    end

    def call
      ActiveRecord::Base.transaction do
        candidate_ids = eligible(change.candidates).pluck(:id)
        keyword = perform!
        Result.new(keyword: keyword, updated_count: rematch(Transaction.where(id: candidate_ids)))
      end
    end

    private

    attr_reader :change, :reapply

    def perform!
      case change.action
      when "create"
        Keyword.find_or_create_by!(parsed_name: change.parsed_name, subcategory_id: change.subcategory_id) { _1.name = change.name }
      when "update"
        change.keyword.tap { _1.update!(name: change.name, subcategory_id: change.subcategory_id) }
      when "delete"
        change.keyword.destroy!
        nil
      end
    end

    def eligible(scope)
      sources = { "none" => [], "uncategorized" => %w[uncategorized], "all" => %w[uncategorized keyword] }.fetch(reapply)
      by_source = scope.where(categorization_source: sources)
      change.keyword ? by_source.or(scope.where(keyword_id: change.keyword.id)) : by_source
    end

    # @return [Integer] transactions whose subcategory changed
    def rematch(scope)
      keywords = Keyword.all.to_a
      fallback_id = Subcategory.other_subcategory.id
      moved = []

      scope.find_each do |transaction|
        match = Matchers::DefaultMatcher.find_best_keyword_match(transaction.name, keywords)
        attrs = { subcategory_id: match&.subcategory_id || fallback_id, keyword_id: match&.id,
                  categorization_source: match ? "keyword" : "uncategorized" }
        next if attrs.all? { |key, value| transaction[key] == value }

        moved << transaction.id if attrs[:subcategory_id] != transaction.subcategory_id
        transaction.update_columns(**attrs, updated_at: Time.current)
      end

      CategorySuggestion.pending.where(parsed_transaction_id: Transaction.where(id: moved).categorized_by_keyword)
                        .update_all(status: "superseded", decided_at: Time.current, updated_at: Time.current)
      moved.size
    end
  end
end
