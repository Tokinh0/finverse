require 'rails_helper'

RSpec.describe MonthlyStatements::Import do
  before { create(:subcategory, :other) }

  def csv_statement(*rows)
    statement_with_file(filename: 'fatura.csv', content_type: 'text/csv', content: sicredi_csv(*rows))
  end

  it 'parses the file, stores the transaction date range and marks the statement processed' do
    statement = csv_statement('05/01/2025;IFOOD;;"R$ 60,28";;;C', '20/01/2025;UBER;;"R$ 15,00";;;C')

    expect(described_class.call(statement)).to be(true)
    expect(statement.reload).to have_attributes(
      status: 'processed',
      first_transaction_date: Date.new(2025, 1, 5),
      last_transaction_date: Date.new(2025, 1, 20)
    )
  end

  it 'marks the statement failed when any line failed' do
    statement = csv_statement('05/01/2025;IFOOD;;"R$ 60,28";;;C')
    allow(Parsers::CsvParser).to receive(:new).and_wrap_original do |original, *args|
      original.call(*args).tap { create(:summary_line, monthly_statement: statement, status: 'failed') }
    end

    described_class.call(statement)

    expect(statement.reload).to be_failed
  end

  it 'rejects unsupported file types' do
    statement = statement_with_file(content: 'x', filename: 'notes.txt', content_type: 'text/plain')

    expect(described_class.call(statement)).to be(false)
    expect(statement.reload).to be_failed
    expect(statement.errors[:file]).to include(/Unsupported file type/)
  end

  it 'rolls back everything the parser created when it raises' do
    statement = csv_statement('05/01/2025;IFOOD;;"R$ 60,28";;;C')
    allow(ActiveRecord::Base).to receive(:transaction).and_wrap_original do |original, &block|
      original.call do
        block.call
        raise 'boom'
      end
    end

    expect(described_class.call(statement)).to be(false)
    expect(statement.transactions.count).to eq(0)
    expect(statement.reload).to be_failed
  end
end
