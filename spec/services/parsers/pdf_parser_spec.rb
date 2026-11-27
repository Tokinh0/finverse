require 'rails_helper'

RSpec.describe Parsers::PdfParser do
  let(:statement) { statement_with_file(content: '%PDF-fake', filename: 'extrato.pdf', content_type: 'application/pdf') }

  before { create(:subcategory, :other) }

  it 'delegates to the layout parser that matches the first page' do
    reader = fake_pdf_reader(text: "Extrato de conta corrente\nPeríodo das movimentações", runs: [])
    allow(PDF::Reader).to receive(:new).and_return(reader)
    layout = instance_double(Parsers::SicrediAccountStatementPdf, call: true)
    allow(Parsers::SicrediAccountStatementPdf).to receive(:new).with(statement, reader).and_return(layout)

    described_class.new(statement).call

    expect(layout).to have_received(:call)
  end

  it 'parses the legacy one-line-per-transaction layout' do
    legacy_text = <<~TEXT
      Extrato
      02/01/2025 COMPRA MERCADO DOC123 -45,90 1.000,00
      03/01/2025 PAGTO FATURA DOC456 -10,00 990,00
      not a transaction line
    TEXT
    allow(PDF::Reader).to receive(:new).and_return(fake_pdf_reader(text: legacy_text, runs: []))

    described_class.new(statement).call

    expect(statement.transactions.pluck(:name, :amount, :transaction_type)).to eq([ [ 'COMPRA MERCADO', 45.9, 'debit' ] ])
    expect(statement.statement_kind).to eq('checking_account')
  end
end
