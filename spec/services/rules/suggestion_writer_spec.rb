require 'rails_helper'

RSpec.describe Rules::SuggestionWriter do
  let!(:fallback) { create(:subcategory, :other) }
  let(:transport) { create(:subcategory, name: 'Transporte') }
  let(:change) { Rules::Change.new(action: 'create', name: 'UBER TRIP', subcategory_id: transport.id) }

  def write(change = self.change)
    described_class.call(change, origin: 'ai', confidence: 0.9, reason: 'Recurring')
  end

  before { 12.times { |i| create(:transaction, name: "OUTRA #{i}", subcategory: fallback) } }

  it 'saves a useful change once' do
    create(:transaction, name: 'UBER TRIP', subcategory: fallback)

    first = write
    expect(first).to have_attributes(status: 'pending', fingerprint: "create|UBER_TRIP|#{transport.id}")
    expect(write).to eq(first)
    expect(RuleSuggestion.count).to eq(1)
  end

  it 'skips rules that would move nothing, are too short, exist already or match too much' do
    expect(write).to be_nil # nothing matches yet
    create(:transaction, name: 'UBER TRIP', subcategory: fallback)
    expect(write(Rules::Change.new(action: 'create', name: 'UB', subcategory_id: transport.id))).to be_nil
    expect(write(Rules::Change.new(action: 'create', name: 'OUTRA', subcategory_id: transport.id))).to be_nil # 12 of 13
    create(:keyword, name: 'UBER TRIP', subcategory: transport)
    expect(write).to be_nil
  end

  it 'skips updates that change nothing' do
    keyword = create(:keyword, name: 'POSTO', subcategory: transport)

    expect(write(Rules::Change.new(action: 'update', keyword: keyword))).to be_nil
  end

  describe 'rejection memory' do
    before do
      3.times { create(:transaction, name: 'UBER TRIP', subcategory: fallback) }
      Rules::Decide.reject(write)
    end

    it 'does not propose a rejected change again while the data is about the same' do
      2.times { create(:transaction, name: 'UBER TRIP', subcategory: fallback) }

      expect(write).to be_nil
    end

    it 'proposes it again once it would move clearly more transactions' do
      5.times { create(:transaction, name: 'UBER TRIP', subcategory: fallback) }

      expect(write).to be_present
    end
  end
end
