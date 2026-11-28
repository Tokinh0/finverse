require 'rails_helper'

RSpec.describe 'Api::V1::Reports' do
  before { create(:transaction, transaction_date: Date.new(2025, 3, 1)) }

  it 'returns the monthly report by category' do
    get '/api/v1/reports/monthly_by_category'

    expect(json.keys).to contain_exactly('credit', 'debit')
    expect(json['debit'].keys).to eq([ '2025-03' ])
  end

  it 'returns the monthly report by subcategory' do
    get '/api/v1/reports/monthly_by_subcategory'

    expect(json['debit']['2025-03']).to include('total' => 10.5)
  end

  it "returns the financial health report" do
    get "/api/v1/reports/financial_health", params: { period: 1 }

    expect(json).to include("as_of" => "2025-03", "period_months" => 1)
    expect(json.keys).to include("summary", "categories", "trends", "year", "savings")
    expect(json["savings"].keys).to include("summary", "opportunities", "subscriptions")
  end

  describe 'GET /reports/categorization_progress' do
    it 'counts transactions per month by how they were categorized' do
      create(:transaction, transaction_date: Date.new(2031, 2, 3), categorization_source: 'keyword')
      create(:transaction, transaction_date: Date.new(2031, 3, 3), categorization_source: 'keyword')
      create(:transaction, transaction_date: Date.new(2031, 3, 9), categorization_source: 'manual')
      create(:transaction, transaction_date: Date.new(2031, 3, 9), categorization_source: 'ai_accepted')
      create(:transaction, transaction_date: Date.new(2031, 3, 9), categorization_source: 'uncategorized')

      get '/api/v1/reports/categorization_progress', params: { months: 2 }

      expect(json).to eq([
        { 'month' => '2031-02', 'total' => 1, 'keyword_share' => 1.0,
          'counts' => { 'keyword' => 1, 'ai_accepted' => 0, 'manual' => 0, 'uncategorized' => 0 } },
        { 'month' => '2031-03', 'total' => 4, 'keyword_share' => 0.25,
          'counts' => { 'keyword' => 1, 'ai_accepted' => 1, 'manual' => 1, 'uncategorized' => 1 } }
      ])
    end
  end
end
