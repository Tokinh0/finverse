require 'rails_helper'

RSpec.describe 'Presenters' do
  describe AssetPresenter do
    it 'serializes the asset and its share of the asset type total' do
      asset = create(:asset, asset_type: 'reserva', current_value: 25)
      create(:asset, asset_type: 'reserva', current_value: 75)

      expect(described_class.new(asset).as_json).to include(id: asset.id, asset_type: 'reserva', current_value: 25.0, percent_by_type: 25.0)
      expect(described_class.new(asset, total_by_type: 50).percent_by_type).to eq(50.0)
    end

    it 'returns 0 when the type total is zero' do
      expect(described_class.new(build(:asset, current_value: 0)).percent_by_type).to eq(0)
    end
  end

  describe CategoryPresenter do
    it 'includes the subcategories' do
      subcategory = create(:subcategory)

      expect(described_class.new(subcategory.category).as_json[:subcategories]).to eq(
        [ { id: subcategory.id, name: subcategory.name, color_code: subcategory.color_code, subcategory_type: 'expense' } ]
      )
    end
  end

  describe SubcategoryPresenter do
    it 'includes the parent category' do
      subcategory = create(:subcategory)

      expect(described_class.new(subcategory).as_json[:category]).to include(id: subcategory.category_id)
    end
  end

  describe KeywordPresenter do
    it 'nests the subcategory and category' do
      keyword = create(:keyword)

      expect(described_class.new(keyword).as_json).to include(
        name: keyword.name, parsed_name: keyword.parsed_name,
        subcategory: a_hash_including(id: keyword.subcategory_id, category: a_hash_including(id: keyword.category.id))
      )
    end
  end

  describe MonthlyStatementPresenter do
    it 'serializes the statement without a file' do
      statement = create(:monthly_statement, first_transaction_date: Date.new(2025, 1, 1))

      expect(described_class.new(statement).as_json).to include(id: statement.id, status: 'unprocessed', url: nil, filename: nil)
    end
  end

  describe SummaryLinePresenter do
    it 'includes the parsed transaction and its category' do
      transaction = create(:transaction, amount: 12.3)
      line = create(:summary_line, parsed_transaction: transaction, monthly_statement: transaction.monthly_statement)

      expect(described_class.new(line).as_json[:parsed_transaction]).to include(
        amount: 12.3, subcategory_name: transaction.subcategory.name, category_name: transaction.subcategory.category.name
      )
    end

    it 'tolerates lines without a transaction' do
      expect(described_class.new(build(:summary_line, status: 'skipped')).as_json[:parsed_transaction][:name]).to be_nil
    end
  end

  describe TransactionPresenter do
    it 'serializes the transaction with its subcategory and category' do
      transaction = create(:transaction, amount: 9.99, transaction_date: Time.zone.parse('2025-04-01 00:00'))

      expect(described_class.new(transaction).as_json).to include(
        amount: 9.99, transaction_date: '2025-04-01', transaction_type: 'debit',
        subcategory: a_hash_including(id: transaction.subcategory_id),
        category: a_hash_including(id: transaction.subcategory.category_id)
      )
    end
  end
end
