require 'rails_helper'

RSpec.describe Portfolio::Dashboard do
  it 'returns the assets with their share of their asset type, and the asset type labels' do
    stock_a = create(:asset, asset_type: 'acoes_nacionais', current_value: 300)
    create(:asset, asset_type: 'acoes_nacionais', current_value: 100)
    reserve = create(:asset, asset_type: 'reserva', current_value: 600)

    result = described_class.call

    expect(result.keys).to contain_exactly(:assets, :asset_types)
    expect(result[:asset_types]).to eq(Asset::ASSET_TYPES)
    expect(result[:assets].find { |a| a[:id] == stock_a.id }).to include(current_value: 300.0, percent_by_type: 75.0)
    expect(result[:assets].find { |a| a[:id] == reserve.id }).to include(percent_by_type: 100.0)
  end

  it 'handles an empty portfolio and zero values' do
    expect(described_class.call).to include(assets: [])

    create(:asset, current_value: 0)
    expect(described_class.call[:assets].first).to include(current_value: 0.0, percent_by_type: 0)
  end
end
