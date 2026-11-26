require 'rails_helper'

RSpec.describe Reports::MonthlyByCategory do
  it 'groups credits and debits by month, category and subcategory, newest month first' do
    food = create(:subcategory, name: 'Food', category: create(:category, name: 'Conforto', color_code: '#ff0000'))
    salary = create(:subcategory, name: 'Salario', category: create(:category, name: 'Ganhos'))
    create(:transaction, subcategory: food, name: 'IFOOD', amount: 10.255, transaction_date: Date.new(2025, 1, 3))
    create(:transaction, subcategory: food, name: 'IFOOD', amount: 5, transaction_date: Date.new(2025, 2, 3))
    create(:transaction, subcategory: salary, name: 'SALARIO', amount: 1000, transaction_type: 'credit',
                         transaction_date: Date.new(2025, 1, 5))

    report = described_class.call

    expect(report[:debit].keys).to eq(%w[2025-02 2025-01])
    expect(report[:debit]['2025-01']['CONFORTO']).to match(
      color_code: '#ff0000',
      subcategories: { 'FOOD' => { total: 10.26, transactions: [hash_including(name: 'IFOOD', transaction_type: 'debit')] } }
    )
    expect(report[:credit]['2025-01']['GANHOS'][:subcategories]['SALARIO'][:total]).to eq(1000.0)
  end
end
