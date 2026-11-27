require 'rails_helper'

RSpec.describe Rules::Decide do
  let!(:fallback) { create(:subcategory, :other) }
  let(:transport) { create(:subcategory, name: 'Transporte') }
  let(:food) { create(:subcategory, name: 'Comida') }
  let!(:open_one) { create(:transaction, name: 'UBER TRIP SP', subcategory: fallback) }
  let(:suggestion) { create(:rule_suggestion, action: 'create', name: 'UBER TRIP', subcategory: transport) }

  it 'accepts: creates the rule, re-applies it and records the impact' do
    result = described_class.accept(suggestion)

    expect(result).to be_success
    expect(result.keyword).to have_attributes(parsed_name: 'UBER_TRIP', subcategory: transport)
    expect(result.updated_count).to eq(1)
    expect(suggestion.reload).to have_attributes(status: 'accepted', match_count_at_decision: 1)
    expect(open_one.reload.subcategory).to eq(transport)
  end

  it 'lets the owner edit the rule before accepting' do
    result = described_class.accept(suggestion, name: 'UBER', subcategory_id: food.id.to_s, reapply: 'none')

    expect(result.keyword).to have_attributes(parsed_name: 'UBER', subcategory: food)
    expect(open_one.reload.subcategory).to eq(fallback)
  end

  it 'rejects and remembers how much the rule would have moved' do
    expect(described_class.reject(suggestion)).to be_success

    expect(suggestion.reload).to have_attributes(status: 'rejected', match_count_at_decision: 1)
    expect(Keyword.count).to eq(0)
  end

  it 'refuses decided suggestions and bad input' do
    described_class.reject(suggestion)
    expect(described_class.accept(suggestion).errors).to eq([ 'This suggestion was already rejected' ])

    other = create(:rule_suggestion, name: 'TAXI', subcategory: transport)
    expect(described_class.accept(other, reapply: 'bogus')).not_to be_success
    expect(other.reload).to be_pending
  end
end
