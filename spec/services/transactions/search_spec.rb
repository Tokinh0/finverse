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

    expect(result.transactions).to eq([ uber, ifood, pay ])
    expect(result).to have_attributes(total_count: 3, total_amount: 5060.0, page: 1, per_page: 50, months: %w[2025-02 2025-01])
  end

  it 'filters by month, including the last day' do
    expect(search(month: '2025-02').transactions).to contain_exactly(ifood, uber)
  end

  it 'ignores an invalid month' do
    expect(search(month: 'feb').total_count).to eq(3)
  end

  it 'filters by subcategory, category and type' do
    expect(search(subcategory_id: salary.id).transactions).to eq([ pay ])
    expect(search(category_id: food.category_id).transactions).to contain_exactly(ifood, uber)
    expect(search(transaction_type: 'credit').transactions).to eq([ pay ])
  end

  it 'searches the name case-insensitively, also in normalized form' do
    expect(search(q: 'ifood').transactions).to eq([ ifood ])
    expect(search(q: 'uber eats').transactions).to eq([ uber ])
    expect(search(q: '100%').transactions).to be_empty
  end

  it 'paginates and caps per_page' do
    result = search(page: 2, per_page: 2)

    expect(result.transactions).to eq([ pay ])
    expect(result.total_count).to eq(3)
    expect(search(per_page: 10_000).per_page).to eq(described_class::MAX_PER_PAGE)
  end

  describe 'date range' do
    it 'filters from..to, including both days' do
      expect(search(from: '2025-02-10', to: '2025-02-28').transactions).to contain_exactly(ifood, uber)
      expect(search(from: '2025-02-11', to: '2025-02-27').transactions).to be_empty
    end

    it 'leaves either end open' do
      expect(search(from: '2025-02-11').transactions).to eq([ uber ])
      expect(search(to: '2025-02-10').transactions).to contain_exactly(ifood, pay)
    end

    it 'swaps a reversed range and reports the range used' do
      result = search(from: '2025-02-28', to: '2025-02-01')

      expect(result.transactions).to contain_exactly(ifood, uber)
      expect([ result.from, result.to ]).to eq([ Date.new(2025, 2, 1), Date.new(2025, 2, 28) ])
    end

    it 'prefers the range over a month, and ignores invalid dates' do
      expect(search(month: '2025-01', from: '2025-02-28').transactions).to eq([ uber ])
      expect(search(from: 'yesterday').total_count).to eq(3)
    end

    it 'reports the first and last transaction dates' do
      expect(search(q: 'ifood')).to have_attributes(first_date: Date.new(2025, 1, 5), last_date: Date.new(2025, 2, 28))
    end
  end

  it 'filters by statement' do
    statement = create(:monthly_statement)
    other = create(:transaction, subcategory: food, monthly_statement: statement)

    expect(search(monthly_statement_id: statement.id).transactions).to eq([ other ])
  end

  describe 'sorting' do
    def names(sort) = search(sort: sort).transactions.map(&:name)

    it 'sorts by date, newest first by default' do
      expect(search.sort).to eq('date_desc')
      expect(names('date_asc')).to eq([ 'SALARIO', 'IFOOD Restaurante', 'UBER EATS' ])
    end

    it 'sorts by amount' do
      expect(names('amount_desc')).to eq([ 'SALARIO', 'IFOOD Restaurante', 'UBER EATS' ])
      expect(names('amount_asc')).to eq([ 'UBER EATS', 'IFOOD Restaurante', 'SALARIO' ])
    end

    it 'sorts by name, ignoring case' do
      create(:transaction, subcategory: food, name: 'amazon', transaction_date: Date.new(2025, 1, 1))

      expect(names('name_asc')).to eq([ 'amazon', 'IFOOD Restaurante', 'SALARIO', 'UBER EATS' ])
      expect(names('name_desc').first).to eq('UBER EATS')
    end

    it 'sorts by category, then subcategory, newest first inside each' do
      food.category.update!(name: 'Alimentacao')
      salary.category.update!(name: 'Ganhos')

      expect(names('category_asc')).to eq([ 'UBER EATS', 'IFOOD Restaurante', 'SALARIO' ])
      expect(names('category_desc')).to eq([ 'SALARIO', 'UBER EATS', 'IFOOD Restaurante' ])
    end

    it 'sorts with a category filter too' do
      expect(search(sort: 'category_asc', category_id: food.category_id).transactions).to eq([ uber, ifood ])
    end

    it 'falls back to the default for an unknown sort' do
      result = search(sort: 'DROP TABLE')

      expect(result.sort).to eq('date_desc')
      expect(result.transactions).to eq([ uber, ifood, pay ])
    end
  end
end
