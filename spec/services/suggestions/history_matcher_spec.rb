require 'rails_helper'

RSpec.describe Suggestions::HistoryMatcher do
  let!(:fallback) { create(:subcategory, :other) }
  let(:bakery) { create(:subcategory, name: 'Padaria') }
  let(:market) { create(:subcategory, name: 'Mercado') }

  def group(name)
    transaction = create(:transaction, name: name, subcategory: fallback, categorization_source: 'uncategorized')
    Suggestions::Candidates::Group.new(merchant_key: Transactions::Merchant.key(transaction), transactions: [ transaction ])
  end

  def confirmed(name, subcategory, source: 'manual')
    create(:transaction, name: name, subcategory: subcategory, categorization_source: source)
  end

  it 'suggests the subcategory the owner picked for the same merchant' do
    3.times { |i| confirmed("PADARIA EXEMPLO #{i}", bakery) }

    match = described_class.call([ group('PADARIA EXEMPLO 99') ])['PADARIA_EXEMPLO']

    expect(match).to have_attributes(subcategory_id: bakery.id, confidence: 0.9)
    expect(match.reason).to include('3 transactions', 'Padaria')
  end

  it 'scales confidence down when the owner was inconsistent' do
    confirmed('PADARIA EXEMPLO', bakery, source: 'ai_accepted')
    confirmed('PADARIA EXEMPLO', bakery)
    confirmed('PADARIA EXEMPLO', market)

    expect(described_class.call([ group('PADARIA EXEMPLO') ])['PADARIA_EXEMPLO'].confidence).to eq(0.53)
  end

  it 'ignores keyword matches and merchants with no history' do
    confirmed('PADARIA EXEMPLO', bakery, source: 'keyword')

    expect(described_class.call([ group('PADARIA EXEMPLO'), group('NOVO LUGAR') ])).to eq({})
  end

  it 'never suggests a subcategory the owner rejected for that merchant' do
    confirmed('PADARIA EXEMPLO', bakery)
    earlier = create(:transaction, name: 'PADARIA EXEMPLO', subcategory: fallback)
    create(:category_suggestion, parsed_transaction: earlier, subcategory: bakery, status: 'rejected')

    expect(described_class.call([ group('PADARIA EXEMPLO') ])).to eq({})
  end

  it "quotes the owner's latest note in the reason" do
    transaction = confirmed('PADARIA EXEMPLO', bakery)
    create(:categorization_event, parsed_transaction: transaction, to_subcategory: bakery, note: 'Breakfast place near work')

    expect(described_class.call([ group('PADARIA EXEMPLO') ])['PADARIA_EXEMPLO'].reason).to end_with('(your note: "Breakfast place near work")')
  end
end
