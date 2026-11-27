require 'rails_helper'

RSpec.describe 'Api::V1::CategorySuggestions' do
  let!(:fallback) { create(:subcategory, :other) }
  let(:bakery) { create(:subcategory, name: 'Padaria') }
  let(:transaction) do
    create(:transaction, name: 'PADARIA SOL', subcategory: fallback, categorization_source: 'uncategorized', transaction_date: Date.new(2025, 3, 4))
  end
  let!(:suggestion) { create(:category_suggestion, parsed_transaction: transaction, subcategory: bakery, confidence: 0.9, reason: 'Bakery') }

  it 'lists pending suggestions with their transaction' do
    get '/api/v1/category_suggestions', params: { month: '2025-03' }

    expect(json.sole).to include(
      'id' => suggestion.id, 'origin' => 'ai', 'confidence' => 0.9, 'reason' => 'Bakery', 'merchant_key' => 'PADARIA_SOL',
      'subcategory' => a_hash_including('id' => bakery.id),
      'transaction' => a_hash_including('id' => transaction.id, 'categorization_source' => 'uncategorized')
    )
    get '/api/v1/category_suggestions', params: { month: '2025-04' }
    expect(json).to be_empty
  end

  it 'accepts, optionally with another subcategory' do
    post "/api/v1/category_suggestions/#{suggestion.id}/accept"

    expect(json['status']).to eq('accepted')
    expect(transaction.reload.categorization_source).to eq('ai_accepted')
  end

  it 'rejects, and refuses to decide twice' do
    post "/api/v1/category_suggestions/#{suggestion.id}/reject"
    expect(json['status']).to eq('rejected')

    post "/api/v1/category_suggestions/#{suggestion.id}/accept"
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'bulk accepts' do
    post '/api/v1/category_suggestions/bulk_accept', params: { min_confidence: 0.85 }

    expect(json).to eq('accepted_count' => 1)
    post '/api/v1/category_suggestions/bulk_accept'
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'shows the pending suggestion on the transaction list' do
    get '/api/v1/transactions'

    expect(json['transactions'].sole['pending_suggestion']).to include('id' => suggestion.id, 'confidence' => 0.9)
    expect(json['transactions'].sole['pending_suggestion']).not_to have_key('transaction')
  end
end
