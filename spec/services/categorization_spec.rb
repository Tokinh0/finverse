require 'rails_helper'

RSpec.describe Categorization do
  let!(:other) { create(:subcategory, :other) }
  let(:entry) { { name: 'IFOOD RESTAURANTE', amount: 42.5, transaction_date: Date.new(2025, 1, 2) } }

  it 'assigns the subcategory of the best matching keyword' do
    keyword = create(:keyword, name: 'IFOOD')

    expect(described_class.call(entry)).to include(subcategory_id: keyword.subcategory_id, name: 'IFOOD RESTAURANTE', amount: 42.5)
  end

  it 'falls back to the "Outros" subcategory' do
    expect(described_class.call(entry)[:subcategory_id]).to eq(other.id)
  end

  it 'keeps an explicit transaction_type' do
    expect(described_class.call(entry.merge(transaction_type: 'credit'))[:transaction_type]).to eq('credit')
  end

  it 'treats negative amounts as debits' do
    expect(described_class.call(entry.merge(name: 'RECEBIMENTO', amount: -1))[:transaction_type]).to eq(:debit)
  end

  it 'infers the type from the keyword lists otherwise' do
    expect(described_class.call(entry.merge(name: 'RECEBIMENTO PIX'))[:transaction_type]).to eq(:credit)
  end
end
