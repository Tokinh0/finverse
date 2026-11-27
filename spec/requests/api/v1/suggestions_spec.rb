require 'rails_helper'

RSpec.describe 'Api::V1::Suggestions' do
  let!(:fallback) { create(:subcategory, :other) }

  it 'summarizes pending suggestions and the latest run' do
    create(:category_suggestion)
    run = create(:suggestion_run, status: 'failed', error_code: 'invalid_key', error_message: 'Rejected')

    get '/api/v1/suggestions/summary'

    expect(json).to include('pending_count' => 1, 'claude_configured' => false)
    expect(json['latest_run']).to include('id' => run.id, 'status' => 'failed', 'error_message' => 'Rejected')
  end

  it 'starts a run for every uncategorized transaction' do
    create(:transaction, subcategory: fallback, categorization_source: 'uncategorized')

    expect { post '/api/v1/suggestion_runs' }.to have_enqueued_job(GenerateSuggestionsJob)
    expect(response).to have_http_status(:created)
    expect(json).to include('status' => 'queued', 'monthly_statement_id' => nil)

    post '/api/v1/suggestion_runs'
    expect(response).to have_http_status(:unprocessable_content)
  end
end
