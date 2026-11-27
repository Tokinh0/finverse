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

  describe 'rules with an amount range' do
    let(:subscription) { create(:subcategory, name: 'Assinatura') }
    let(:purchases) { create(:subcategory, name: 'Compras') }

    before do
      create(:keyword, name: 'AMAZON', subcategory: subscription, max_amount: 99.99)
      create(:keyword, name: 'AMAZON', subcategory: purchases, min_amount: 100)
    end

    it 'picks the rule whose range contains the amount' do
      expect(described_class.call(entry.merge(name: 'AMAZON MARKETPLACE', amount: 79.9))[:subcategory_id]).to eq(subscription.id)
      expect(described_class.call(entry.merge(name: 'AMAZON MARKETPLACE', amount: 250))[:subcategory_id]).to eq(purchases.id)
      expect(described_class.call(entry.merge(name: 'AMAZON MARKETPLACE', amount: -250))[:subcategory_id]).to eq(purchases.id)
    end

    it 'prefers a ranged rule over a plain one with the same score, and falls back to the plain one outside the range' do
      plain = create(:subcategory, name: 'Geral')
      create(:keyword, name: 'LOJA', subcategory: plain)
      create(:keyword, name: 'LOJA', subcategory: purchases, min_amount: 500)

      expect(described_class.call(entry.merge(name: 'LOJA X', amount: 600))[:subcategory_id]).to eq(purchases.id)
      expect(described_class.call(entry.merge(name: 'LOJA X', amount: 50))[:subcategory_id]).to eq(plain.id)
    end
  end
end
