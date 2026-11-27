require 'rails_helper'

RSpec.describe Transactions::MarkUnknown do
  let!(:fallback) { create(:subcategory, :other) }
  let(:food) { create(:subcategory, name: 'Food') }
  let(:transaction) { create(:transaction, name: 'PIX 1', subcategory: fallback, categorization_source: 'uncategorized') }

  it 'marks the transaction and dismisses its suggestion, without moving or rejecting anything' do
    suggestion = create(:category_suggestion, parsed_transaction: transaction, subcategory: food)

    expect(described_class.call(transaction)).to be_success

    expect(transaction.reload).to have_attributes(subcategory: fallback, categorization_source: 'uncategorized')
    expect(transaction).to be_marked_unknown
    expect(suggestion.reload).to be_dismissed
    expect(Suggestions::Rejections.by_merchant([ 'PIX' ])).to eq({})
    expect(CategorizationEvent.count).to eq(0)
  end

  it 'only marks uncategorized transactions' do
    categorized = create(:transaction, subcategory: food, categorization_source: 'manual')

    expect(described_class.call(categorized).errors).to eq([ 'Only uncategorized transactions can be marked' ])
    expect(categorized.reload).not_to be_marked_unknown
  end

  it 'can be undone, and categorizing by hand clears it' do
    described_class.call(transaction)
    described_class.undo(transaction)
    expect(transaction.reload).not_to be_marked_unknown

    described_class.call(transaction)
    Transactions::Recategorize.call(transaction.reload, subcategory_id: food.id)
    expect(transaction.reload).not_to be_marked_unknown
  end

  it 'keeps marked transactions out of suggestion runs and rule re-application' do
    described_class.call(transaction)
    other = create(:transaction, name: 'PIX 2', subcategory: fallback, categorization_source: 'uncategorized')

    expect(Suggestions::Candidates.call.flat_map(&:transactions)).to eq([ other ])

    change = Rules::Change.new(action: 'create', name: 'PIX', subcategory_id: food.id)
    preview = Rules::Preview.call(change)
    expect(preview.rows.find { _1.transaction == transaction }.kept).to be(true)
    Rules::Apply.call(change, reapply: 'all')
    expect(transaction.reload.subcategory).to eq(fallback)
    expect(other.reload.subcategory).to eq(food)
  end
end
