require 'rails_helper'

RSpec.describe 'Rules::Health and Rules::LocalSuggester' do
  let!(:fallback) { create(:subcategory, :other) }
  let(:transport) { create(:subcategory, name: 'Transporte') }
  let(:food) { create(:subcategory, name: 'Comida') }

  def override(keyword, to:, name: 'POSTO')
    transaction = create(:transaction, name: name, subcategory: to, categorization_source: 'manual')
    create(:categorization_event, parsed_transaction: transaction, overridden_keyword: keyword, to_subcategory: to)
  end

  describe Rules::Health do
    it 'flags overridden, unused and overlapping rules' do
      overridden = create(:keyword, name: 'POSTO', subcategory: food)
      create(:transaction, name: 'POSTO A', subcategory: food, categorization_source: 'keyword', keyword: overridden)
      3.times { override(overridden, to: transport) }
      unused = create(:keyword, name: 'NADA', subcategory: food)
      tie_a = create(:keyword, name: 'LOJA', subcategory: food)
      tie_b = create(:keyword, name: 'CASA', subcategory: transport)
      create(:transaction, name: 'LOJA CASA', subcategory: food, categorization_source: 'keyword', keyword: tie_a)

      health = described_class.call

      expect(health[overridden.id]).to have_attributes(matches: 1, overrides: 3, top_override_subcategory_id: transport.id,
                                                       flags: [ 'overridden' ])
      expect(health[unused.id].flags).to eq([ 'unused' ])
      expect(health[tie_a.id]).to have_attributes(flags: [ 'overlapping' ], overlapping_keyword_ids: [ tie_b.id ])
      expect(health[tie_b.id].flags).to contain_exactly('unused', 'overlapping')
    end
  end

  describe Rules::LocalSuggester do
    it 'suggests a rule after the owner corrected the same merchant three times' do
      2.times { |i| override(nil, to: transport, name: "TAXI AMIGO #{i}") }
      expect(described_class.call).to be_empty

      override(nil, to: transport, name: 'TAXI AMIGO 9')
      suggestion = described_class.call.sole

      expect(suggestion).to have_attributes(action: 'create', parsed_name: 'TAXI_AMIGO', subcategory: transport, origin: 'local',
                                            confidence: 0.9)
      expect(suggestion.reason).to include('3 transactions')
    end

    it 'does not suggest a rule that an existing rule already covers' do
      create(:keyword, name: 'TAXI', subcategory: transport)
      3.times { override(nil, to: transport, name: 'TAXI AMIGO') }

      expect(described_class.call).to be_empty
    end

    it 'suggests moving a rule the owner keeps overriding to the same place' do
      keyword = create(:keyword, name: 'POSTO', subcategory: food)
      3.times { override(keyword, to: transport) }

      expect(described_class.call).to include(have_attributes(action: 'update', keyword: keyword, subcategory: transport))
    end

    it 'gives the nudge for the merchant just corrected' do
      3.times { override(nil, to: transport, name: 'TAXI AMIGO') }

      expect(described_class.nudge_for(Transaction.last)).to have_attributes(parsed_name: 'TAXI_AMIGO')
    end
  end

  it 'does not flag rules for the same keyword with separate ranges as overlapping' do
    small = create(:keyword, name: 'AMAZON', subcategory: food, max_amount: 99.99)
    create(:keyword, name: 'AMAZON', subcategory: transport, min_amount: 100)
    create(:transaction, name: 'AMAZON', amount: 50, subcategory: food, categorization_source: 'keyword', keyword: small)

    expect(Rules::Health.call[small.id].flags).not_to include('overlapping')
  end
end
