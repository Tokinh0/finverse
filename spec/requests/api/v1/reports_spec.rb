require 'rails_helper'

RSpec.describe 'Api::V1::Reports' do
  before { create(:transaction, transaction_date: Date.new(2025, 3, 1)) }

  it 'returns the monthly report by category' do
    get '/api/v1/reports/monthly_by_category'

    expect(json.keys).to contain_exactly('credit', 'debit')
    expect(json['debit'].keys).to eq(['2025-03'])
  end

  it 'returns the monthly report by subcategory' do
    get '/api/v1/reports/monthly_by_subcategory'

    expect(json['debit']['2025-03']).to include('total' => 10.5)
  end
end
