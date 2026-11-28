require 'rails_helper'

RSpec.describe 'Api::V1::PortfolioDashboard' do
  it 'returns the assets and asset types' do
    create(:asset, asset_type: 'reserva', current_value: 100)

    get '/api/v1/portfolio_dashboard'

    expect(json.keys).to contain_exactly('assets', 'asset_types')
    expect(json['asset_types']).to eq(Asset::ASSET_TYPES)
    expect(json['assets'].size).to eq(1)
  end
end
