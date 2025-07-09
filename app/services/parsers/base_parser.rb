module Parsers
  class BaseParser
    attr_reader :monthly_statement

    def initialize(monthly_statement)
      @monthly_statement = monthly_statement
    end

    def create_transaction(entry, raw_content)
      categorized = Categorization.call(entry)
      if categorized[:subcategory_id].nil?
        binding.pry
      end
      transaction = Transaction.find_or_initialize_by(categorized.merge(monthly_statement_id: monthly_statement.id))

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
