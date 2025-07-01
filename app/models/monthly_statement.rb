class MonthlyStatement < ApplicationRecord
  has_many :transactions, dependent: :destroy
  enum statement_type: { credit: 'credit', debit: 'debit' }
  enum status: { unprocessed: 'unprocessed', processed: 'processed' }
  has_one_attached :file

  def parse_file
    case file.content_type
    when 'application/pdf'
      Parsers::PdfParser.new(self).call
    when 'text/csv'
      Parsers::CsvParser.new(self).call
    else
      raise "Unsupported file type: #{file.content_type}"
    end
    
    set_statement_type
    set_transaction_date_range
    self.status = :processed
    save
  end

  def set_statement_type
    if file.filename.to_s.end_with?('.csv')
      self.statement_type = :credit
    else
      self.statement_type = :debit
    end
  end

  def set_transaction_date_range
    self.first_transaction_date = transactions.minimum(:transaction_date)
    self.last_transaction_date = transactions.maximum(:transaction_date)
  end
end
