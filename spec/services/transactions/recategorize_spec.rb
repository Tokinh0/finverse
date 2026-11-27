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
end
