require 'rails_helper'

RSpec.describe Suggestions::Decide do
  let!(:fallback) { create(:subcategory, :other) }
  let(:bakery) { create(:subcategory, name: 'Padaria') }
  let(:market) { create(:subcategory, name: 'Mercado') }
  let(:transaction) { create(:transaction, name: 'PADARIA SOL', subcategory: fallback, categorization_source: 'uncategorized') }
  let(:suggestion) { create(:category_suggestion, parsed_transaction: transaction, subcategory: bakery) }

  it 'accepts: moves the transaction as ai_accepted and records the event' do
    expect(described_class.accept(suggestion)).to be_success

    expect(suggestion.reload).to be_accepted
    expect(transaction.reload).to have_attributes(subcategory: bakery, categorization_source: 'ai_accepted')
    expect(transaction.categorization_events.sole).to have_attributes(to_source: 'ai_accepted', to_subcategory: bakery)
  end

  it 'accepting with another subcategory moves it as manual and remembers the rejection' do
    described_class.accept(suggestion, subcategory_id: market.id.to_s)

    expect(suggestion.reload).to be_rejected
    expect(transaction.reload).to have_attributes(subcategory: market, categorization_source: 'manual')
  end

  it 'rejects without moving the transaction' do
    expect(described_class.reject(suggestion)).to be_success

    expect(suggestion.reload).to be_rejected
    expect(transaction.reload.subcategory).to eq(fallback)
  end

  it 'refuses decided suggestions and supersedes ones whose transaction moved meanwhile' do
    described_class.reject(suggestion)
    expect(described_class.accept(suggestion).errors).to eq([ 'This suggestion was already rejected' ])

    other = create(:category_suggestion, parsed_transaction: create(:transaction, categorization_source: 'manual'))
    expect(described_class.accept(other)).not_to be_success
    expect(other.reload).to be_superseded
  end

  it 'rolls back the decision when the transaction cannot move' do
    result = described_class.accept(suggestion, subcategory_id: 0)

    expect(result).not_to be_success
    expect(suggestion.reload).to be_pending
    expect(transaction.reload.subcategory).to eq(fallback)
  end

  it 'a manual recategorize supersedes the pending suggestion' do
    Transactions::Recategorize.call(transaction.tap { suggestion }, subcategory_id: market.id)

    expect(suggestion.reload).to be_superseded
  end

  describe '.bulk_accept' do
    let!(:high) { suggestion.tap { _1.update!(confidence: 0.95) } }
    let!(:low) { create(:category_suggestion, confidence: 0.5, subcategory: market,
                                              parsed_transaction: create(:transaction, name: 'MERCADO 1', subcategory: fallback)) }

    it 'accepts everything above a confidence' do
      expect(described_class.bulk_accept(min_confidence: '0.9')).to eq(1)
      expect([ high.reload.status, low.reload.status ]).to eq(%w[accepted pending])
    end

    it 'accepts everything for one merchant' do
      expect(described_class.bulk_accept(merchant_key: 'MERCADO')).to eq(1)
      expect(low.reload).to be_accepted
    end

    it 'needs a filter' do
      expect { described_class.bulk_accept }.to raise_error(ArgumentError)
    end
  end
end
