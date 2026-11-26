require 'rails_helper'

RSpec.describe Portfolio::Dashboard do
  it 'returns assets, asset type labels and the allocation per asset type' do
    stock_a = create(:asset, asset_type: 'acoes_nacionais', current_value: 300, color_code: '#111111')
    create(:asset, asset_type: 'acoes_nacionais', current_value: 100)
    create(:asset, asset_type: 'reserva', current_value: 600, color_code: '#222222')

    result = described_class.call

    expect(result[:asset_types]).to eq(Asset::ASSET_TYPES)
    expect(result[:assets].find { |a| a[:id] == stock_a.id }).to include(current_value: 300.0, percent_by_type: 75.0)
    expect(result[:portfolioData]).to contain_exactly(
      { name: 'acoes_nacionais', value: 400.0, percentage: '40.0%', color: '#111111' },
      { name: 'reserva', value: 600.0, percentage: '60.0%', color: '#222222' }
    )
  end

  it 'handles an empty portfolio and zero values' do
    expect(described_class.call).to include(assets: [], portfolioData: [])

    create(:asset, current_value: 0)
    expect(described_class.call[:portfolioData].first).to include(value: 0.0, percentage: '0%')
  end
end
