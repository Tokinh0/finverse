require 'rails_helper'

RSpec.describe 'Api::V1::Alerts' do
  let!(:first) { create(:transaction, name: 'NETFLIX', amount: 55.9, transaction_date: Date.new(2025, 7, 10)) }
  let!(:second) { create(:transaction, name: 'NETFLIX', amount: 55.9, transaction_date: Date.new(2025, 7, 10)) }

  it 'lists the alerts of the latest month' do
    get '/api/v1/alerts'

    expect(json['month']).to eq('2025-07')
    expect(json['alerts']).to contain_exactly(a_hash_including(
      'kind' => 'duplicate', 'dismissed' => false, 'transaction' => a_hash_including('id' => second.id),
      'details' => { 'related_transaction_id' => first.id }
    ))
  end

  it 'dismisses and restores an alert' do
    post '/api/v1/alerts/dismiss', params: { transaction_id: second.id, kind: 'duplicate' }
    expect(response).to have_http_status(:no_content)
    post '/api/v1/alerts/dismiss', params: { transaction_id: second.id, kind: 'duplicate' } # idempotent
    expect(response).to have_http_status(:no_content)

    get '/api/v1/alerts', params: { month: '2025-07' }
    expect(json['alerts']).to be_empty

    delete '/api/v1/alerts/dismiss', params: { transaction_id: second.id, kind: 'duplicate' }
    get '/api/v1/alerts', params: { month: '2025-07' }
    expect(json['alerts'].size).to eq(1)
  end

  it 'rejects unknown kinds' do
    post '/api/v1/alerts/dismiss', params: { transaction_id: second.id, kind: 'whatever' }

    expect(response).to have_http_status(:unprocessable_content)
  end
end
