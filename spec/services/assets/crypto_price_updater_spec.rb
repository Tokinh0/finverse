require 'rails_helper'

RSpec.describe Assets::CryptoPriceUpdater do
  let(:asset) { create(:asset, asset_type: 'criptomoedas', ticker: 'BTC', quantity: 2, current_value: 1) }

  it 'updates the unit and current value from the price service' do
    allow(CriptomoedasPriceService).to receive(:fetch_price).with('BTC', currency: 'brl').and_return(BigDecimal('100'))

    expect(described_class.new(asset).update_price).to be(true)
    expect(asset.reload).to have_attributes(last_uploaded_unit_value: 100, current_value: 200)
  end

  it 'falls back to the last known unit value when the price service fails' do
    asset.update!(last_uploaded_unit_value: 50)
    allow(CriptomoedasPriceService).to receive(:fetch_price).and_return(nil)

    expect(described_class.new(asset).update_price).to be(true)
    expect(asset.reload.current_value).to eq(100)
  end

  it 'returns false without any price available' do
    allow(CriptomoedasPriceService).to receive(:fetch_price).and_return(nil)

    expect(described_class.new(asset).update_price).to be(false)
  end

  it 'skips unsupported tickers and empty positions' do
    expect(CriptomoedasPriceService).not_to receive(:fetch_price)

    expect(described_class.new(build(:asset, ticker: 'ABCD', quantity: 1)).update_price).to be(false)
    expect(described_class.new(build(:asset, ticker: 'BTC', quantity: 0)).update_price).to be(false)
  end

  describe '.update_all_prices' do
    it 'updates every supported crypto asset and returns the count' do
      asset
      create(:asset, asset_type: 'acoes_nacionais', ticker: 'BTC')
      allow(CriptomoedasPriceService).to receive(:fetch_price).and_return(BigDecimal('10'))

      expect(described_class.update_all_prices).to eq(1)
    end
  end

  describe '.for' do
    it 'only builds updaters for crypto assets' do
      expect(described_class.for(asset)).to be_a(described_class)
      expect(described_class.for(build(:asset, asset_type: 'reserva'))).to be_nil
    end
  end
end
