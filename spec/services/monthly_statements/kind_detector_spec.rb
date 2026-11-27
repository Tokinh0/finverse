require 'rails_helper'

RSpec.describe MonthlyStatements::KindDetector do
  def pdf_statement
    statement_with_file(content: '%PDF-fake', filename: 'x.pdf', content_type: 'application/pdf')
  end

  it 'treats card CSV exports as credit card statements' do
    statement = statement_with_file(content: sicredi_csv, filename: 'x.csv', content_type: 'text/csv')

    expect(described_class.call(statement)).to eq('credit_card')
  end

  it 'detects the PDF layout from the first page' do
    allow(PDF::Reader).to receive(:new).and_return(fake_pdf_reader(text: "Mastercard Black final 1234\nResumo da fatura", runs: []))

    expect(described_class.call(pdf_statement)).to eq('credit_card')
  end

  it 'treats the legacy PDF layout as a checking account statement' do
    allow(PDF::Reader).to receive(:new).and_return(fake_pdf_reader(text: 'Extrato', runs: []))

    expect(described_class.call(pdf_statement)).to eq('checking_account')
  end

  it 'returns nil for other file types' do
    expect(described_class.call(statement_with_file(content: 'x', filename: 'x.txt', content_type: 'text/plain'))).to be_nil
  end
end
