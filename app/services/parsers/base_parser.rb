module Parsers
  class BaseParser
    attr_reader :monthly_statement

    def initialize(monthly_statement)
      @monthly_statement = monthly_statement
    end

    def create_summary(status:, content:, error: nil, transaction: nil)
      SummaryLine.find_or_create_by(
        monthly_statement: monthly_statement,
        status: status,
        error: error,
        parsed_transaction: transaction,
        content: content.to_json
      )
    end

    def create_transaction(entry, raw_content)
      categorized = Categorization.call(entry)
      transaction = Transaction.find_or_create_by(categorized.merge(monthly_statement_id: monthly_statement.id))

      if transaction.persisted?
        create_summary(status: 'processed', content: raw_content, transaction: transaction)
      else
        create_summary(status: 'failed', content: raw_content, error: transaction.errors.full_messages.join(', '))
      end
    end
  end
end
