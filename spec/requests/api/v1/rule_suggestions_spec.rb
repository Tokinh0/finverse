require 'rails_helper'

RSpec.describe 'Api::V1::RuleSuggestions' do
  let!(:fallback) { create(:subcategory, :other) }
  let(:transport) { create(:subcategory, name: 'Transporte', category: create(:category, name: 'Mobilidade')) }
  let!(:open_one) { create(:transaction, name: 'UBER TRIP SP', subcategory: fallback, transaction_date: Date.new(2025, 3, 2)) }
  let!(:suggestion) { create(:rule_suggestion, name: 'UBER TRIP', subcategory: transport, reason: 'Recurs', confidence: 0.93) }

  it 'lists pending suggestions with a live preview' do
    get '/api/v1/rule_suggestions'

    expect(json.sole).to include(
      'id' => suggestion.id, 'action' => 'create', 'confidence' => 0.93, 'reason' => 'Recurs', 'keyword' => nil,
      'proposed' => { 'name' => 'UBER TRIP', 'subcategory' => a_hash_including('id' => transport.id, 'category' => 'Mobilidade'),
                      'min_amount' => nil, 'max_amount' => nil }
    )
    expect(json.sole['preview']).to include('total' => 1, 'matched' => 1, 'counts' => { 'uncategorized' => 1, 'keyword' => 0, 'kept' => 0 })
    expect(json.sole['preview']['transactions'].sole).to include(
      'id' => open_one.id, 'transaction_date' => '2025-03-02', 'kept' => false,
      'from' => a_hash_including('id' => fallback.id), 'to' => a_hash_including('id' => transport.id)
    )
  end

  it 'accepts with edits and a re-apply scope' do
    post "/api/v1/rule_suggestions/#{suggestion.id}/accept", params: { name: 'UBER', reapply: 'uncategorized' }

    expect(json).to include('updated_count' => 1, 'keyword' => a_hash_including('parsed_name' => 'UBER'))
    expect(json['suggestion']).to include('status' => 'accepted', 'preview' => nil)
    expect(open_one.reload.subcategory).to eq(transport)
  end

  it 'rejects, and refuses to decide twice' do
    post "/api/v1/rule_suggestions/#{suggestion.id}/reject"
    expect(json['suggestion']['status']).to eq('rejected')

    post "/api/v1/rule_suggestions/#{suggestion.id}/accept"
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'counts pending rule suggestions in the summary' do
    get '/api/v1/suggestions/summary'

    expect(json).to include('pending_count' => 1, 'pending_rule_count' => 1, 'pending_category_count' => 0)
  end
end
