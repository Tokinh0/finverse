require 'rails_helper'

RSpec.describe Transactions::Search do
  let(:food) { create(:subcategory, name: 'Food') }
  let(:salary) { create(:subcategory, name: 'Salario') }
  let!(:ifood) { create(:transaction, subcategory: food, name: 'IFOOD Restaurante', amount: 40, transaction_date: Date.new(2025, 2, 10)) }
  let!(:uber) { create(:transaction, subcategory: food, name: 'UBER EATS', amount: 20, transaction_date: Date.new(2025, 2, 28)) }
  let!(:pay) { create(:transaction, subcategory: salary, name: 'SALARIO', amount: 5000, transaction_type: 'credit', transaction_date: Date.new(2025, 1, 5)) }

  def search(params = {})
    described_class.call(ActionController::Parameters.new(params).permit!)
  end

  it 'returns everything newest first with totals and the available months' do
    result = search

    expect(result.transactions).to eq([uber, ifood, pay])
    expect(result).to have_attributes(total_count: 3, total_amount: 5060.0, page: 1, per_page: 50, months: %w[2025-02 2025-01])
  end

  it 'filters by month, including the last day' do
    expect(search(month: '2025-02').transactions).to contain_exactly(ifood, uber)
  end

  it 'ignores an invalid month' do
    expect(search(month: 'feb').total_count).to eq(3)
  end

  it 'filters by subcategory, category and type' do
    expect(search(subcategory_id: salary.id).transactions).to eq([pay])
    expect(search(category_id: food.category_id).transactions).to contain_exactly(ifood, uber)
    expect(search(transaction_type: 'credit').transactions).to eq([pay])
  end

  it 'searches the name case-insensitively, also in normalized form' do
    expect(search(q: 'ifood').transactions).to eq([ifood])
    expect(search(q: 'uber eats').transactions).to eq([uber])
    expect(search(q: '100%').transactions).to be_empty
  end

  it 'paginates and caps per_page' do
    result = search(page: 2, per_page: 2)

    expect(result.transactions).to eq([pay])
    expect(result.total_count).to eq(3)
    expect(search(per_page: 10_000).per_page).to eq(described_class::MAX_PER_PAGE)
  end
end
