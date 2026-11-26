module MonthlyStatements
  # Parses an uploaded statement file into transactions and summary lines.
  #
  # The parsing runs in a DB transaction: if the parser raises, nothing it created
  # is kept and the statement is marked as failed with the error on `errors[:file]`.
  class Import
    PARSERS = {
      'application/pdf' => Parsers::PdfParser,
      'text/csv' => Parsers::CsvParser
    }.freeze

    UnsupportedFileType = Class.new(StandardError)

    def self.call(monthly_statement)
      new(monthly_statement).call
    end

    def initialize(monthly_statement)
      @monthly_statement = monthly_statement
    end

    # @return [Boolean] true when the file was parsed (individual lines may still have failed)
    def call
      ActiveRecord::Base.transaction do
        parser_class.new(monthly_statement).call

        monthly_statement.first_transaction_date = monthly_statement.transactions.minimum(:transaction_date)
        monthly_statement.last_transaction_date = monthly_statement.transactions.maximum(:transaction_date)
        monthly_statement.status = monthly_statement.summary_lines.failed.exists? ? 'failed' : 'processed'
        monthly_statement.save!
      end

      true
    rescue StandardError => e
      Rails.logger.error("Statement #{monthly_statement.id} import failed: #{e.class}: #{e.message}")
      monthly_statement.update(status: 'failed')
      monthly_statement.errors.add(:file, e.message)
      false
    end

    private

    attr_reader :monthly_statement

    def parser_class
      content_type = monthly_statement.file.content_type
      PARSERS.fetch(content_type) { raise UnsupportedFileType, "Unsupported file type: #{content_type}" }
    end
  end
end
