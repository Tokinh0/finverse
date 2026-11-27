require 'rails_helper'

RSpec.describe Parsers::SicrediAccountStatementPdf do
  let(:first_page_text) { "Extrato de conta corrente\nPeríodo das movimentações" }
  let(:reader) do
    fake_pdf_reader(
      text: first_page_text,
      runs: [
        [ 40, 700, '12/08/2026' ], [ 120, 700, 'PAGAMENTO PIX - 123 JOHN' ], [ 500, 700, '- R$ 19,00' ],
        [ 120, 690, 'Saldo do dia 12/08/2026' ],
        [ 40, 650, '13/08/2026' ], [ 120, 650, 'RECEBIMENTO PIX' ], [ 500, 650, '+ R$ 1.000,50' ],
        [ 40, 600, '14/08/2026' ], [ 120, 600, 'PAGTO FATURA CARTAO' ], [ 500, 600, '- R$ 300,00' ],
        [ 40, 550, '15/08/2026' ], [ 120, 550, 'SEM VALOR' ]
      ]
    )
  end
  let(:statement) { create(:monthly_statement) }

  before { create(:subcategory, :other) }

  it 'detects its layout from the first page' do
    expect(described_class.matches?(first_page_text)).to be(true)
    expect(described_class.matches?('Resumo da fatura')).to be(false)
  end

  it 'turns each dated row into a transaction signed by its amount' do
    described_class.new(statement, reader).call

    expect(statement.transactions.order(:transaction_date).pluck(:name, :amount, :transaction_type)).to eq(
      [ [ 'PAGAMENTO PIX 123 JOHN', 19.0, 'debit' ], [ 'RECEBIMENTO PIX', 1000.5, 'credit' ] ]
    )
    expect(statement.statement_kind).to eq('checking_account')
  end

  it 'ignores card bill payments and records rows without an amount as failed' do
    described_class.new(statement, reader).call

    expect(statement.transactions.where("name LIKE 'PAGTO%'")).to be_empty
    expect(statement.summary_lines.failed.pluck(:error)).to eq([ 'amount_not_found' ])
  end
end
