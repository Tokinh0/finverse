require 'rails_helper'

RSpec.describe 'Api::V1::Assets' do
  let(:params) { { asset: { asset_type: 'reserva', ticker: 'CDB', description: 'Reserva', current_value: '1500.5', rating: 5, quantity: 1 } } }

  it 'lists and shows assets through the presenter' do
    asset = create(:asset, current_value: 10)

    get '/api/v1/assets'
    expect(json).to contain_exactly(a_hash_including('id' => asset.id, 'current_value' => 10.0, 'percent_by_type' => 100.0))

    get "/api/v1/assets/#{asset.id}"
    expect(json).to include('ticker' => asset.ticker)
  end

  it 'creates an asset' do
    expect { post '/api/v1/assets', params: params }.to change(Asset, :count).by(1)
    expect(response).to have_http_status(:created)
    expect(json).to include('asset_type' => 'reserva', 'current_value' => 1500.5)
  end

  it 'updates an asset and returns the presented asset' do
    asset = create(:asset)

    patch "/api/v1/assets/#{asset.id}", params: { asset: { current_value: '42' } }

    expect(response).to have_http_status(:ok)
    expect(json).to include('current_value' => 42.0, 'percent_by_type' => 100.0)
  end

  it 'destroys an asset' do
    asset = create(:asset)

    expect { delete "/api/v1/assets/#{asset.id}" }.to change(Asset, :count).by(-1)
  end
end
