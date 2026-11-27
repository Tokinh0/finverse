module Rules
  # Shows what a rule change would do, by running the real keyword matcher with the rules as
  # they would be after the change. Nothing is saved.
  #
  # A transaction is affected when its subcategory would change. Transactions the owner
  # categorized (manual or accepted) or marked "no idea" are never moved by rules; they are
  # reported as `kept`.
  class Preview
    OWNER_SOURCES = %w[manual ai_accepted].freeze
    DEFAULT_LIMIT = 50

    Row = Struct.new(:transaction, :from_subcategory_id, :to_subcategory_id, :to_keyword_id, :kept, keyword_init: true)
    Result = Struct.new(:rows, :counts, :claimed, keyword_init: true) do
      # Transactions a re-apply of "all" would move.
      def total
        counts[:uncategorized] + counts[:keyword]
      end

      # Transactions the changed rule would be the best match for, including owner decisions it
      # leaves alone and ones already in its subcategory. A rule for a merchant the owner keeps
      # fixing by hand moves nothing today but is still useful. For a delete: what it moves.
      def matched
        claimed || total
      end
    end

    def self.call(change, **options)
      new(change, **options).call
    end

    def initialize(change, limit: DEFAULT_LIMIT)
      @change = change
      @limit = limit
    end

    def call
      @claimed = 0
      rows = moves.to_a
      counts = {
        uncategorized: rows.count { !_1.kept && _1.transaction.categorized_by_uncategorized? },
        keyword: rows.count { !_1.kept && _1.transaction.categorized_by_keyword? },
        kept: rows.count(&:kept)
      }
      Result.new(rows: rows.sort_by { [ _1.kept ? 1 : 0, -_1.transaction.transaction_date.to_i ] }.first(limit), counts: counts,
                 claimed: change.action == "delete" ? nil : @claimed)
    end

    # Every transaction whose subcategory the change would alter, with where it would go.
    def moves
      keywords = change.keywords_after(Keyword.all.to_a)
      fallback_id = Subcategory.other_subcategory.id

      Enumerator.new do |yielder|
        change.candidates.includes(:subcategory).find_each do |transaction|
          match = Matchers::DefaultMatcher.find_best_keyword_match(transaction.name, keywords, amount: transaction.amount)
          @claimed = @claimed.to_i + 1 if match && changed_rule?(match)
          to_subcategory_id = match&.subcategory_id || fallback_id
          next if to_subcategory_id == transaction.subcategory_id

          yielder << Row.new(transaction: transaction, from_subcategory_id: transaction.subcategory_id,
                             to_subcategory_id: to_subcategory_id, to_keyword_id: match&.id,
                             kept: OWNER_SOURCES.include?(transaction.categorization_source) || transaction.marked_unknown?)
        end
      end
    end

    private

    attr_reader :change, :limit

    def changed_rule?(keyword)
      change.action == "create" ? keyword.new_record? : keyword.id == change.keyword&.id
    end
  end
end
