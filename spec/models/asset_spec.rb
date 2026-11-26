require 'rails_helper'

RSpec.describe Asset do
  it 'stores the asset type label and exposes the key through the enum' do
    asset = create(:asset, asset_type: 'criptomoedas')

    expect(asset.reload.asset_type).to eq('criptomoedas')
    expect(asset.read_attribute_before_type_cast(:asset_type)).to eq('Criptomoedas')
    expect(described_class.criptomoedas).to contain_exactly(asset)
  end
end
