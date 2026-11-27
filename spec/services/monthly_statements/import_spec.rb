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

  describe 'duplicate imports' do
    let(:rows) { [ '05/01/2025;IFOOD;;"R$ 60,28";;;C', '06/01/2025;UBER;;"R$ 15,00";;;C', '07/01/2025;LOJA;;"R$ 9,90";;;C' ] }

    it 'rejects a file that was already imported' do
      described_class.call(csv_statement(*rows))
      again = csv_statement(*rows)

      expect(described_class.call(again)).to be(false)
      expect(again.errors[:file]).to include(/already imported/)
      expect(again.transactions).to be_empty
    end

    it 'rejects a different file whose transactions were already imported' do
      described_class.call(csv_statement(*rows))
      other_file = csv_statement(*rows, '')

      expect(described_class.call(other_file)).to be(false)
      expect(other_file.errors[:file]).to include(/3 of 3 transactions were already imported/)
      expect(other_file.reload.transactions).to be_empty
    end

    it 'imports a statement that only partly overlaps an earlier one' do
      described_class.call(csv_statement(*rows))
      next_month = csv_statement(rows.first, '05/02/2025;IFOOD;;"R$ 60,28";;;C', '06/02/2025;UBER;;"R$ 15,00";;;C')

      expect(described_class.call(next_month)).to be(true)
      expect(next_month.transactions.count).to eq(3)
    end

    it 'allows re-importing a file whose earlier import failed' do
      failed = csv_statement(*rows)
      failed.update!(status: 'failed')
      again = csv_statement(*rows)

      expect(described_class.call(again)).to be(true)
    end
  end
end
