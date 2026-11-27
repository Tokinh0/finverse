module Transactions
  # Moves a transaction to another subcategory and/or fixes its type.
  #
  # With `keyword:` it also creates a Keyword pointing at the new subcategory, so future imports
  # categorize this merchant correctly. With `apply_to_matching: true` it then re-runs matching on
  # every other transaction whose name contains the keyword, moving the ones for which the new
  # keyword is now the best match. Transactions matched more strongly by another keyword stay put.
  class Recategorize
    Result = Struct.new(:success?, :transaction, :keyword, :updated_count, :errors, keyword_init: true)

    def self.call(transaction, **args)
      new(transaction, **args).call
    end

    def initialize(transaction, subcategory_id: nil, transaction_type: nil, keyword: nil, apply_to_matching: false)
      @transaction = transaction
      @subcategory_id = subcategory_id.presence
      @transaction_type = transaction_type.presence
      @keyword_name = keyword.to_s.strip.presence
      @apply_to_matching = ActiveModel::Type::Boolean.new.cast(apply_to_matching)
    end

    def call
      ActiveRecord::Base.transaction do
        transaction.assign_attributes({ subcategory_id: subcategory_id, transaction_type: transaction_type }.compact)
        transaction.save!

        keyword = create_keyword! if keyword_name
        updated = keyword && apply_to_matching ? apply_keyword(keyword) : 0

        Result.new(success?: true, transaction: transaction, keyword: keyword, updated_count: updated, errors: [])
      end
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      record_errors = e.respond_to?(:record) ? e.record.errors.full_messages : [e.message]
      Result.new(success?: false, transaction: transaction, keyword: nil, updated_count: 0, errors: record_errors)
    end

    private

    attr_reader :transaction, :subcategory_id, :transaction_type, :keyword_name, :apply_to_matching

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
                              .where('parsed_name LIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(keyword.parsed_name)}%")

      ids = candidates.select { |t| Matchers::DefaultMatcher.find_best_keyword_match(t.name, keywords)&.id == keyword.id }.map(&:id)
      Transaction.where(id: ids).update_all(subcategory_id: keyword.subcategory_id, updated_at: Time.current)
    end
  end
end
