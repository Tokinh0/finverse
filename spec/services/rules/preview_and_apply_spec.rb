require 'rails_helper'

RSpec.describe 'Rules::Preview and Rules::Apply' do
  let!(:fallback) { create(:subcategory, :other) }
  let(:transport) { create(:subcategory, name: 'Transporte') }
  let(:food) { create(:subcategory, name: 'Comida') }

  def txn(name, subcategory: fallback, source: 'uncategorized', keyword: nil)
    create(:transaction, name: name, subcategory: subcategory, categorization_source: source, keyword: keyword)
  end

  describe 'creating a rule' do
    let(:change) { Rules::Change.new(action: 'create', name: 'UBER TRIP', subcategory_id: transport.id) }
    let!(:open_one) { txn('UBER TRIP SP') }
    # Matched by a weaker rule today: "UBER TRIP EATS SP" only contains the name (score 1).
    let!(:by_other_rule) do
      txn('UBER TRIP EATS', subcategory: food, source: 'keyword', keyword: create(:keyword, name: 'UBER TRIP EATS SP', subcategory: food))
    end
    let!(:owner_choice) { txn('UBER TRIP RJ', subcategory: food, source: 'manual') }
    let!(:unrelated) { txn('PADARIA') }

    it 'previews what would move, keeping owner decisions' do
      preview = Rules::Preview.call(change)

      expect(preview.counts).to eq(uncategorized: 1, keyword: 1, kept: 1)
      expect(preview.total).to eq(2)
      expect(preview.rows.map { [ _1.transaction, _1.to_subcategory_id, _1.kept ] }).to contain_exactly(
        [ open_one, transport.id, false ], [ by_other_rule, transport.id, false ], [ owner_choice, transport.id, true ]
      )
      expect(Keyword.count).to eq(1) # nothing saved
    end

    it 'applies to uncategorized transactions by default scope' do
      result = Rules::Apply.call(change, reapply: 'uncategorized')

      expect(result.keyword).to have_attributes(parsed_name: 'UBER_TRIP', subcategory: transport)
      expect(result.updated_count).to eq(1)
      expect(open_one.reload).to have_attributes(subcategory: transport, categorization_source: 'keyword', keyword_id: result.keyword.id)
      expect(by_other_rule.reload.subcategory).to eq(food)
    end

    it 'with "all" also moves transactions other rules matched, never owner decisions' do
      Rules::Apply.call(change, reapply: 'all')

      expect(by_other_rule.reload.subcategory).to eq(transport)
      expect(owner_choice.reload).to have_attributes(subcategory: food, categorization_source: 'manual')
    end

    it 'with "none" only creates the rule' do
      expect(Rules::Apply.call(change, reapply: 'none').updated_count).to eq(0)
      expect(open_one.reload).to be_categorized_by_uncategorized
    end

    it 'supersedes pending category suggestions of the transactions it moves' do
      suggestion = create(:category_suggestion, parsed_transaction: open_one)

      Rules::Apply.call(change, reapply: 'uncategorized')

      expect(suggestion.reload).to be_superseded
    end
  end

  it 'updating a rule moves its own transactions even with "none"' do
    keyword = create(:keyword, name: 'POSTO', subcategory: food)
    matched = txn('POSTO SHELL', subcategory: food, source: 'keyword', keyword: keyword)

    Rules::Apply.call(Rules::Change.new(action: 'update', keyword: keyword, subcategory_id: transport.id), reapply: 'none')

    expect(keyword.reload.subcategory).to eq(transport)
    expect(matched.reload).to have_attributes(subcategory: transport, keyword_id: keyword.id)
  end

  it 'deleting a rule sends its transactions to the next best rule or back to uncategorized' do
    keyword = create(:keyword, name: 'POSTO SHELL', subcategory: food)
    backup = create(:keyword, name: 'SHELL', subcategory: transport)
    both = txn('POSTO SHELL 1', subcategory: food, source: 'keyword', keyword: keyword)
    only = txn('POSTO_SHELL', subcategory: food, source: 'keyword', keyword: keyword)
    change = Rules::Change.new(action: 'delete', keyword: keyword)

    expect(Rules::Preview.call(change).total).to eq(2)
    Rules::Apply.call(change, reapply: 'none')

    expect(Keyword.exists?(keyword.id)).to be(false)
    expect(both.reload).to have_attributes(subcategory: transport, keyword_id: backup.id)
    expect(only.reload).to have_attributes(subcategory: transport, keyword_id: backup.id)
  end

  it 'rejects an unknown reapply scope' do
    expect { Rules::Apply.call(Rules::Change.new(action: 'create', name: 'X', subcategory_id: food.id), reapply: 'everything') }
      .to raise_error(ArgumentError)
  end

  describe 'amount ranges' do
    it 'previews and applies a rule only to transactions inside its range' do
      small = txn('AMAZON PRIME', subcategory: fallback)
      large = txn('AMAZON COMPRA', subcategory: fallback).tap { _1.update!(amount: 350) }
      small.update!(amount: 19.9)
      change = Rules::Change.new(action: 'create', name: 'AMAZON', subcategory_id: food.id, max_amount: '99.99')

      expect(change.fingerprint).to eq("create|AMAZON|#{food.id}||99.99")
      expect(Rules::Preview.call(change).rows.map(&:transaction)).to eq([ small ])
      result = Rules::Apply.call(change, reapply: 'uncategorized')

      expect(result.keyword).to have_attributes(max_amount: 99.99, min_amount: nil)
      expect(small.reload.subcategory).to eq(food)
      expect(large.reload.subcategory).to eq(fallback)
    end

    it 'updates a range and keeps the current bounds unless given' do
      keyword = create(:keyword, name: 'AMAZON', subcategory: food, max_amount: 99.99)

      expect(Rules::Change.new(action: 'update', keyword: keyword, subcategory_id: transport.id).max_amount).to eq(99.99)
      expect(Rules::Change.new(action: 'update', keyword: keyword, max_amount: nil).amount_range?).to be(false)
      expect(Rules::Change.new(action: 'update', keyword: keyword)).to be_no_op
      expect(Rules::Change.new(action: 'update', keyword: keyword, max_amount: 50)).not_to be_no_op
    end
  end
end
