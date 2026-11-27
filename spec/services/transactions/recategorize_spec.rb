require 'rails_helper'

RSpec.describe Transactions::Recategorize do
  let!(:fallback) { create(:subcategory, :other) }
  let(:food) { create(:subcategory, name: 'Food') }
  let(:transaction) { create(:transaction, subcategory: fallback, name: 'LANCHONETE EXEMPLO') }

  it 'moves the transaction and fixes its type' do
    result = described_class.call(transaction, subcategory_id: food.id, transaction_type: 'credit')

    expect(result).to be_success
    expect(transaction.reload).to have_attributes(subcategory: food, transaction_type: 'credit')
    expect(result.keyword).to be_nil
  end

  it 'creates a keyword for the new subcategory' do
    result = described_class.call(transaction, subcategory_id: food.id, keyword: 'IFD')

    expect(result.keyword).to have_attributes(parsed_name: 'IFD', subcategory: food)
  end

  it 'reuses an existing keyword of that subcategory' do
    existing = create(:keyword, name: 'ifd', subcategory: food)

    expect(described_class.call(transaction, subcategory_id: food.id, keyword: 'IFD').keyword).to eq(existing)
  end

  it 'moves other transactions the new keyword now matches best' do
    other = create(:transaction, subcategory: fallback, name: 'IFD PIZZARIA')
    unrelated = create(:transaction, subcategory: fallback, name: 'MERCADO')
    stronger = create(:subcategory, name: 'Pizza')
    create(:keyword, name: 'IFD PIZZARIA SP', subcategory: stronger) # does not beat "IFD" for this name
    exact = create(:transaction, subcategory: stronger, name: 'IFD_EXACT')
    create(:keyword, name: 'IFD_EXACT', subcategory: stronger) # exact match beats "IFD"

    result = described_class.call(transaction, subcategory_id: food.id, keyword: 'IFD', apply_to_matching: 'true')

    expect(result.updated_count).to eq(1)
    expect(other.reload.subcategory).to eq(food)
    expect(unrelated.reload.subcategory).to eq(fallback)
    expect(exact.reload.subcategory).to eq(stronger)
  end

  it 'does not touch other transactions unless asked' do
    other = create(:transaction, subcategory: fallback, name: 'IFD PIZZARIA')

    described_class.call(transaction, subcategory_id: food.id, keyword: 'IFD')

    expect(other.reload.subcategory).to eq(fallback)
  end

  it 'rolls back and reports errors for invalid input' do
    result = described_class.call(transaction, subcategory_id: food.id, transaction_type: 'bogus')

    expect(result).not_to be_success
    expect(result.errors.first).to match(/bogus/)
    expect(transaction.reload.subcategory).to eq(fallback)
  end

  describe 'categorization tracking' do
    it 'marks the transaction manual and records the correction' do
      result = described_class.call(transaction, subcategory_id: food.id)

      expect(result.transaction.reload).to have_attributes(categorization_source: 'manual', keyword_id: nil)
      expect(transaction.categorization_events.sole).to have_attributes(
        from_subcategory: fallback, to_subcategory: food, from_source: 'uncategorized', to_source: 'manual',
        overridden_keyword_id: nil, merchant_key: 'LANCHONETE_EXEMPLO'
      )
    end

    it 'remembers which keyword the owner overrode' do
      keyword = create(:keyword, name: 'LANCHONETE', subcategory: create(:subcategory, name: 'Snacks'))
      transaction.update!(subcategory: keyword.subcategory, keyword: keyword, categorization_source: 'keyword')

      described_class.call(transaction, subcategory_id: food.id)

      expect(transaction.categorization_events.sole).to have_attributes(from_source: 'keyword', overridden_keyword_id: keyword.id)
    end

    it 'records nothing when only the type changes' do
      described_class.call(transaction, transaction_type: 'credit')

      expect(CategorizationEvent.count).to eq(0)
      expect(transaction.reload.categorization_source).to eq('uncategorized')
    end

    it 'marks transactions moved by the new keyword as categorized by it' do
      other = create(:transaction, subcategory: fallback, name: 'IFD PIZZARIA')

      result = described_class.call(transaction, subcategory_id: food.id, keyword: 'IFD', apply_to_matching: true)

      expect(other.reload).to have_attributes(categorization_source: 'keyword', keyword_id: result.keyword.id)
      expect(other.categorization_events).to be_empty
    end
  end

  describe 'reason' do
    it "keeps the owner's reason on the correction, tidied and capped" do
      described_class.call(transaction, subcategory_id: food.id, reason: "  rent for the\n flat  #{'x' * 400}")

      note = transaction.categorization_events.sole.note
      expect(note).to start_with('rent for the flat x')
      expect(note.length).to eq(300)
    end

    it 'ignores a blank reason' do
      described_class.call(transaction, subcategory_id: food.id, reason: '  ')

      expect(transaction.categorization_events.sole.note).to be_nil
    end
  end

  it 'creates a keyword limited to an amount range' do
    result = described_class.call(transaction, subcategory_id: food.id, keyword: 'LANCHONETE', min_amount: '5', max_amount: '')

    expect(result.keyword).to have_attributes(parsed_name: 'LANCHONETE', min_amount: 5, max_amount: nil)
  end
end
