require 'rails_helper'

RSpec.describe 'Api::V1::PortfolioDashboard' do
  it 'returns the assets, asset types and allocation' do
    create(:asset, asset_type: 'reserva', current_value: 100)

    get '/api/v1/portfolio_dashboard'

    expect(json).to include(
      'asset_types' => Asset::ASSET_TYPES,
      'portfolioData' => [ a_hash_including('name' => 'reserva', 'value' => 100.0, 'percentage' => '100.0%') ]
    )
    expect(json['assets'].size).to eq(1)
  end
end
