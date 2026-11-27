require 'rails_helper'

RSpec.describe Parsers::SicrediCreditCardPdf do
  let(:first_page_text) { "Mastercard Black final 1234\nResumo da fatura\nVencimento 10/01/2026" }
  let(:reader) do
    fake_pdf_reader(
      text: first_page_text,
      runs: [
        [ 40, 700, '23/dez 18:52' ], [ 240, 700, 'Lanchonete Exemplo Ltda' ], [ 500, 700, 'R$ 60,28' ],
        [ 40, 650, '02/jan 10:00' ], [ 240, 650, 'Loja Parcelada' ], [ 350, 650, '02/10' ], [ 500, 650, 'R$ 100,00' ],
        [ 40, 600, '05/jan 09:00' ], [ 240, 600, 'Pagamento 000000000' ], [ 500, 600, '-R$ 1.500,00' ],
        [ 40, 550, '06/jan 09:00' ], [ 240, 550, 'Estorno Loja' ], [ 500, 550, '-R$ 10,00' ]
      ]
    )
  end
  let(:statement) { create(:monthly_statement) }

  before { create(:subcategory, :other) }

  it 'detects its layout from the first page' do
    expect(described_class.matches?(first_page_text)).to be(true)
    expect(described_class.matches?('Extrato de conta corrente')).to be(false)
  end

  it 'infers the year from the due date' do
    described_class.new(statement, reader).call

    expect(statement.transactions.find_by(name: 'Lanchonete Exemplo Ltda').transaction_date.to_date).to eq(Date.new(2025, 12, 23))
    expect(statement.transactions.find_by(name: 'Loja Parcelada').transaction_date.to_date).to eq(Date.new(2026, 1, 2))
  end

  it 'stores purchases as debits, refunds as credits and skips bill payments' do
    described_class.new(statement, reader).call

    expect(statement.transactions.pluck(:name, :transaction_type)).to contain_exactly(
      [ 'Lanchonete Exemplo Ltda', 'debit' ], [ 'Loja Parcelada', 'debit' ], [ 'Estorno Loja', 'credit' ]
    )
  end
end
