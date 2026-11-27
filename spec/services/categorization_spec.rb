require 'rails_helper'

RSpec.describe Categorization do
  let!(:other) { create(:subcategory, :other) }
  let(:entry) { { name: 'IFOOD RESTAURANTE', amount: 42.5, transaction_date: Date.new(2025, 1, 2) } }

  it 'assigns the subcategory of the best matching keyword' do
    keyword = create(:keyword, name: 'IFOOD')

    expect(described_class.call(entry)).to include(
      subcategory_id: keyword.subcategory_id, name: 'IFOOD RESTAURANTE', amount: 42.5,
      keyword_id: keyword.id, categorization_source: 'keyword'
    )
  end

  it 'falls back to the "Outros" subcategory and marks the entry uncategorized' do
    expect(described_class.call(entry)).to include(subcategory_id: other.id, keyword_id: nil, categorization_source: 'uncategorized')
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

  it 'loads keywords and the fallback once per instance' do
    create(:keyword, name: 'IFOOD')
    categorization = described_class.new
    allow(Keyword).to receive(:all).and_call_original
    allow(Subcategory).to receive(:other_subcategory).and_call_original

    3.times { categorization.call(entry.merge(name: 'NOTHING MATCHES')) }

    expect(Keyword).to have_received(:all).once
    expect(Subcategory).to have_received(:other_subcategory).once
  end
end
