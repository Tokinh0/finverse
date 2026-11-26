require 'rails_helper'

RSpec.describe Keywords::TypeInference do
  # Keyword lists come from spec/fixtures/seed_data/default_data.jsonc
  it 'returns credit for names matching a credit keyword' do
    expect(described_class.call('RECEBIMENTO_PIX')).to eq(:credit)
  end

  it 'returns debit for names matching a debit keyword' do
    expect(described_class.call('COMPRA_CARTAO')).to eq(:debit)
  end

  it 'returns ignored for names matching an ignored keyword' do
    expect(described_class.call('PAGTO_FATURA_CARTAO')).to eq(:ignored)
  end

  it 'prefers the strongest match' do
    expect(described_class.call('SALARIO')).to eq(:credit)
  end

  it 'falls back to debit when nothing matches' do
    expect(described_class.call('XYZ_UNKNOWN_NAME')).to eq(:debit)
  end
end
