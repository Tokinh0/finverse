module Parsers
  class BaseParser
    include StringUtils

    attr_reader :monthly_statement

    def initialize(monthly_statement)
      @monthly_statement = monthly_statement
    end

    def create_transaction(entry, raw_content)
      # Always a new record: identical purchases (same day, name and amount) are
      # legitimate separate transactions and must not be merged.
      transaction = Transaction.new(categorization.call(entry))
      transaction.monthly_statement = monthly_statement

      if transaction.save
        SummaryLine.find_or_create_by(
          monthly_statement: monthly_statement,
          status: 'processed',
          parsed_transaction: transaction,
          content: raw_content.to_json
        )
      else
        SummaryLine.find_or_create_by(
          monthly_statement: monthly_statement,
          status: 'failed',
          error: transaction.errors.full_messages.join(', '),
          content: raw_content.to_json
        )
      end
    end

    # One Categorization per import, so keywords and the fallback subcategory are loaded once
    # instead of once per row.
    def categorization
      @categorization ||= Categorization.new
    end

    def create_failed_summary(raw_content, error)
      SummaryLine.create!(
        monthly_statement: monthly_statement,
        status: 'failed',
        error: error,
        content: raw_content.to_json
      )
    end
  end
end
