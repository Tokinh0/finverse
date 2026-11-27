require 'rails_helper'

RSpec.describe 'Api::V1::Transactions' do
  let!(:fallback) { create(:subcategory, :other) }
  let(:food) { create(:subcategory, name: 'Food') }

  describe 'GET /api/v1/transactions' do
    it 'returns presented transactions with pagination meta' do
      transaction = create(:transaction, subcategory: food, name: 'IFOOD', amount: 12.5, transaction_date: Date.new(2025, 3, 2))

      get '/api/v1/transactions', params: { month: '2025-03', per_page: 10 }

      expect(json['transactions']).to contain_exactly(a_hash_including(
        'id' => transaction.id, 'amount' => 12.5, 'transaction_date' => '2025-03-02',
        'subcategory' => a_hash_including('id' => food.id), 'category' => a_hash_including('id' => food.category_id)
      ))
      expect(json['meta']).to include('total_count' => 1, 'total_amount' => 12.5, 'page' => 1, 'per_page' => 10, 'months' => [ '2025-03' ])
    end
  end

  describe 'PATCH /api/v1/transactions/:id' do
    it 're-categorizes and returns the keyword and updated count' do
      transaction = create(:transaction, subcategory: fallback, name: 'IFD BURGUER')
      create(:transaction, subcategory: fallback, name: 'IFD PIZZA')

      patch "/api/v1/transactions/#{transaction.id}",
            params: { transaction: { subcategory_id: food.id, keyword: 'IFD', apply_to_matching: true } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json['transaction']['subcategory']['id']).to eq(food.id)
      expect(json['keyword']).to include('parsed_name' => 'IFD')
      expect(json['updated_count']).to eq(1)
    end

    it 'responds 422 with errors' do
      transaction = create(:transaction, subcategory: fallback)

      patch "/api/v1/transactions/#{transaction.id}", params: { transaction: { subcategory_id: 0 } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['errors']).to include('Subcategory must exist')
    end

    it 'nudges the owner to create a rule after a few manual fixes of the same merchant' do
      2.times do
        earlier = create(:transaction, name: 'TAXI AMIGO', subcategory: food, categorization_source: 'manual')
        create(:categorization_event, parsed_transaction: earlier, to_subcategory: food)
      end
      third = create(:transaction, name: 'TAXI AMIGO', subcategory: fallback, categorization_source: 'uncategorized')

      patch "/api/v1/transactions/#{third.id}", params: { transaction: { subcategory_id: food.id } }, as: :json

      expect(json['rule_nudge']).to include('action' => 'create', 'origin' => 'local',
                                            'proposed' => a_hash_including('name' => 'TAXI AMIGO'))
    end

    it 'sends no nudge for a first fix' do
      transaction = create(:transaction, name: 'TAXI AMIGO', subcategory: fallback)

      patch "/api/v1/transactions/#{transaction.id}", params: { transaction: { subcategory_id: food.id } }, as: :json

      expect(json['rule_nudge']).to be_nil
    end

    it 'saves the reason for the change' do
      transaction = create(:transaction, name: 'PIX MARIA', subcategory: fallback)

      patch "/api/v1/transactions/#{transaction.id}", params: { transaction: { subcategory_id: food.id, reason: 'Monthly rent' } }, as: :json

      expect(transaction.categorization_events.sole.note).to eq('Monthly rent')
    end
  end

  describe '"no idea"' do
    let(:transaction) { create(:transaction, name: 'PIX 1', subcategory: fallback, categorization_source: 'uncategorized') }

    it 'marks and unmarks a transaction, and filters by the mark' do
      post "/api/v1/transactions/#{transaction.id}/unknown"
      expect(json).to include('id' => transaction.id, 'unknown_marked' => true)

      create(:transaction, name: 'OTHER', subcategory: fallback)
      get '/api/v1/transactions', params: { unknown: 'true' }
      expect(json['transactions'].map { _1['id'] }).to eq([ transaction.id ])

      delete "/api/v1/transactions/#{transaction.id}/unknown"
      expect(json['unknown_marked']).to be(false)
    end

    it 'refuses categorized transactions' do
      post "/api/v1/transactions/#{create(:transaction, subcategory: food, categorization_source: 'manual').id}/unknown"

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'answers a suggestion with "no idea"' do
      suggestion = create(:category_suggestion, parsed_transaction: transaction, subcategory: food)

      post "/api/v1/category_suggestions/#{suggestion.id}/dont_know"

      expect(json['status']).to eq('dismissed')
      expect(transaction.reload).to be_marked_unknown
    end
  end
end
