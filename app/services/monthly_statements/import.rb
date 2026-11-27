module MonthlyStatements
  # Parses an uploaded statement file into transactions and summary lines.
  #
  # The parsing runs in a DB transaction: if the parser raises, nothing it created
  # is kept and the statement is marked as failed with the error on `errors[:file]`.
  class Import
    PARSERS = {
      "application/pdf" => Parsers::PdfParser,
      "text/csv" => Parsers::CsvParser
    }.freeze

    UnsupportedFileType = Class.new(StandardError)
    DuplicateStatement = Class.new(StandardError)

    # A new file counts as already imported when at least this share of its transactions
    # (same day, name and amount) already exists in other statements.
    DUPLICATE_SHARE = 0.9
    DUPLICATE_MIN_TRANSACTIONS = 3

    def self.call(monthly_statement)
      new(monthly_statement).call
    end

    def initialize(monthly_statement)
      @monthly_statement = monthly_statement
    end

    # @return [Boolean] true when the file was parsed (individual lines may still have failed)
    def call
      ensure_new_file!

      ActiveRecord::Base.transaction do
        parser_class.new(monthly_statement).call
        ensure_new_transactions!

        monthly_statement.first_transaction_date = monthly_statement.transactions.minimum(:transaction_date)
        monthly_statement.last_transaction_date = monthly_statement.transactions.maximum(:transaction_date)
        monthly_statement.status = monthly_statement.summary_lines.failed.exists? ? "failed" : "processed"
        monthly_statement.save!
      end

      true
    rescue StandardError => e
      Rails.logger.error("Statement #{monthly_statement.id} import failed: #{e.class}: #{e.message}")
      monthly_statement.update(status: "failed")
      monthly_statement.errors.add(:file, e.message)
      false
    end

    private

    attr_reader :monthly_statement

    def ensure_new_file!
      checksum = monthly_statement.file.blob.checksum
      existing = MonthlyStatement.where.not(id: monthly_statement.id).where.not(status: "failed")
                                 .joins(file_attachment: :blob)
                                 .find_by(active_storage_blobs: { checksum: checksum })
      raise DuplicateStatement, I18n.t("statements.already_imported", id: existing.id) if existing
    end

    def ensure_new_transactions!
      rows = monthly_statement.transactions.pluck(:transaction_date, :parsed_name, :amount).map { |row| row_key(*row) }
      return if rows.size < DUPLICATE_MIN_TRANSACTIONS

      dates = rows.map(&:first)
      existing = Transaction.where.not(monthly_statement_id: monthly_statement.id)
                            .where(transaction_date: dates.min.beginning_of_day..dates.max.end_of_day)
                            .pluck(:transaction_date, :parsed_name, :amount)
                            .map { |row| row_key(*row) }
                            .tally
      already_imported = rows.count do |key|
        next false unless existing[key].to_i.positive?

        existing[key] -= 1
        true
      end
      return if already_imported < rows.size * DUPLICATE_SHARE

      raise DuplicateStatement, I18n.t("statements.transactions_already_imported", count: already_imported, total: rows.size)
    end

    def row_key(date, parsed_name, amount)
      [ date.to_date, parsed_name, amount.to_d.round(2) ]
    end

    def parser_class
      content_type = monthly_statement.file.content_type
      PARSERS.fetch(content_type) { raise UnsupportedFileType, I18n.t("statements.unsupported_file_type", type: content_type) }
    end
  end
end
