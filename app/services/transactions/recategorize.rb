module Transactions
  # Moves a transaction to another subcategory and/or fixes its type.
  #
  # With `keyword:` it also creates a Keyword pointing at the new subcategory, so future imports
  # categorize this merchant correctly. With `apply_to_matching: true` it then re-runs matching on
  # every other transaction whose name contains the keyword, moving the ones for which the new
  # keyword is now the best match. Transactions matched more strongly by another keyword stay put.
  #
  # `source:` is "manual" (the owner picked it) or "ai_accepted" (the owner accepted a suggestion
  # as is). Pending suggestions for every transaction this moves are marked superseded.
  class Recategorize
    SOURCES = %w[manual ai_accepted].freeze
    Result = Struct.new(:success?, :transaction, :keyword, :updated_count, :errors, keyword_init: true)

    def self.call(transaction, **args)
      new(transaction, **args).call
    end

    def initialize(transaction, subcategory_id: nil, transaction_type: nil, keyword: nil, apply_to_matching: false,
                   source: "manual")
      raise ArgumentError, "Unknown source: #{source}" unless SOURCES.include?(source)

      @source = source
      @transaction = transaction
      @subcategory_id = subcategory_id.presence
      @transaction_type = transaction_type.presence
      @keyword_name = keyword.to_s.strip.presence
      @apply_to_matching = ActiveModel::Type::Boolean.new.cast(apply_to_matching)
    end

    def call
      ActiveRecord::Base.transaction do
        transaction.assign_attributes({ subcategory_id: subcategory_id, transaction_type: transaction_type }.compact)
        moved = transaction.subcategory_id_changed?
        record_correction if moved
        transaction.save!
        supersede_suggestions([ transaction.id ]) if moved

        keyword = create_keyword! if keyword_name
        updated = keyword && apply_to_matching ? apply_keyword(keyword) : 0

        Result.new(success?: true, transaction: transaction, keyword: keyword, updated_count: updated, errors: [])
      end
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      record_errors = e.respond_to?(:record) ? e.record.errors.full_messages : [ e.message ]
      Result.new(success?: false, transaction: transaction, keyword: nil, updated_count: 0, errors: record_errors)
    end

    private

    attr_reader :transaction, :subcategory_id, :transaction_type, :keyword_name, :apply_to_matching, :source

    # The owner chose this subcategory by hand. The event keeps what it replaced, so repeated
    # corrections of a merchant (or of one keyword's matches) can become rule suggestions.
    def record_correction
      transaction.categorization_events.build(
        from_subcategory_id: transaction.subcategory_id_was,
        to_subcategory_id: transaction.subcategory_id,
        from_source: transaction.categorization_source,
        to_source: source,
        overridden_keyword_id: transaction.categorized_by_keyword? ? transaction.keyword_id : nil,
        merchant_key: Transactions::Merchant.key(transaction)
      )
      transaction.assign_attributes(categorization_source: source, keyword_id: nil)
    end

    # Reuses the keyword when the subcategory already has it.
    def create_keyword!
      Keyword.find_or_create_by!(
        parsed_name: StringUtils.default_string_parse(keyword_name),
        subcategory_id: transaction.subcategory_id
      ) { |keyword| keyword.name = keyword_name }
    end

    def apply_keyword(keyword)
      keywords = Keyword.all.to_a
      candidates = Transaction.where.not(id: transaction.id)
                              .where.not(subcategory_id: keyword.subcategory_id)
                              .where("parsed_name LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(keyword.parsed_name)}%")

      ids = candidates.select { |t| Matchers::DefaultMatcher.find_best_keyword_match(t.name, keywords)&.id == keyword.id }.map(&:id)
      supersede_suggestions(ids)
      Transaction.where(id: ids).update_all(
        subcategory_id: keyword.subcategory_id, keyword_id: keyword.id, categorization_source: "keyword", updated_at: Time.current
      )
    end

    def supersede_suggestions(transaction_ids)
      CategorySuggestion.pending.where(parsed_transaction_id: transaction_ids)
                        .update_all(status: "superseded", decided_at: Time.current, updated_at: Time.current)
    end
  end
end
