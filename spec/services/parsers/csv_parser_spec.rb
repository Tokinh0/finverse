require 'rails_helper'

RSpec.describe Parsers::CsvParser do
  before { create(:subcategory, :other) }

  let(:statement) do
    statement_with_file(
      filename: 'fatura.csv', content_type: 'text/csv',
      content: sicredi_csv(
        '05/01/2025;IFOOD RESTAURANTE;;"R$ 60,28";;;Cartao final 1',
        '06/01/2025;LOJA GRANDE;;"R$ 1.234,56";;;Cartao final 1',
        '07/01/2025;PAG FAT DEB CC;;"R$ 500,00";;;Cartao final 1',
        'Total da fatura;;;"R$ 9,99";;;'
      )
    )
  end

  it 'creates a debit transaction per purchase row' do
    described_class.new(statement).call

    expect(statement.transactions.order(:transaction_date).pluck(:name, :amount, :transaction_type)).to eq(
      [ [ 'IFOOD RESTAURANTE', 60.28, 'debit' ], [ 'LOJA GRANDE', 1234.56, 'debit' ] ]
    )
    expect(statement.summary_lines.processed.count).to eq(2)
  end

  it 'stores refunds (negative amounts) as credits' do
    refund = statement_with_file(
      filename: 'fatura.csv', content_type: 'text/csv',
      content: sicredi_csv('08/01/2025;ESTORNO LOJA;;"R$ -45,90";;;Cartao final 1')
    )

    described_class.new(refund).call

    expect(refund.transactions.pluck(:name, :amount, :transaction_type)).to eq([ [ 'ESTORNO LOJA', 45.9, 'credit' ] ])
  end

  it 'ignores card bill payments and records malformed rows as skipped' do
    described_class.new(statement).call

    expect(statement.transactions.where(name: 'PAG FAT DEB CC')).to be_empty
    expect(statement.summary_lines.skipped.pluck(:error)).to eq([ 'malformed_row' ])
  end

  it 'keeps a failed summary line when a transaction cannot be saved' do
    allow_any_instance_of(Transaction).to receive(:save).and_return(false)

    described_class.new(statement).call

    expect(statement.summary_lines.failed.count).to eq(2)
    expect(statement.transactions).to be_empty
  end
end
