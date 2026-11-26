require 'rails_helper'

RSpec.describe Reports::MonthlyBySubcategory do
  it 'totals each month per subcategory and per subcategory type' do
    food = create(:subcategory, name: 'Food', subcategory_type: 'expense', color_code: '#ff0000')
    savings = create(:subcategory, name: 'Poupanca', subcategory_type: 'investment')
    create(:transaction, subcategory: food, name: 'IFOOD', amount: 30, transaction_date: Date.new(2025, 1, 3))
    create(:transaction, subcategory: food, name: 'UBER EATS', amount: 20, transaction_date: Date.new(2025, 1, 4))
    create(:transaction, subcategory: savings, name: 'APLICACAO', amount: 100, transaction_date: Date.new(2025, 1, 5))

    month = described_class.call[:debit]['2025-01']

    expect(month).to include(total: 150.0, total_expended: 50.0, total_invested: 100.0, total_received: 0, total_transfered: 0)
    expect(month[:subcategories]).to include(
      a_hash_including(name: 'FOOD', total: 50.0, color_code: '#ff0000',
                       transactions: contain_exactly(a_hash_including(transaction_date: '03/01/2025'), a_hash_including(name: 'UBER_EATS')))
    )
  end
end
