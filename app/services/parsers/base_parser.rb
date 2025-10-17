module Parsers
  class BaseParser
    attr_reader :monthly_statement

    def initialize(monthly_statement)
      @monthly_statement = monthly_statement
    end

    def create_transaction(entry, raw_content)
      transaction = Transaction.find_or_initialize_by(Categorization.call(entry))
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
          parsed_transaction: transaction,
          content: raw_content.to_json
        )
      end
    end
  end
end
