require 'rails_helper'

RSpec.describe CriptomoedasPriceService do
  let(:coingecko) { %r{api\.coingecko\.com/api/v3/simple/price} }

  it 'returns the CoinGecko price' do
    stub_request(:get, coingecko).with(query: { ids: 'bitcoin', vs_currencies: 'brl' })
      .to_return(body: { bitcoin: { brl: 350_000.5 } }.to_json)

    expect(described_class.fetch_price('btc', currency: 'brl')).to eq(BigDecimal('350000.5'))
  end

  it 'falls back to CoinCap and converts USD to BRL' do
    stub_request(:get, coingecko).to_return(status: 500)
    stub_request(:get, 'https://api.coincap.io/v2/assets/ETH').to_return(body: { data: { priceUsd: '2000' } }.to_json)
    stub_request(:get, 'https://api.coingecko.com/api/v3/exchange_rates')
      .to_return(body: { rates: { brl: { value: 5.5 } } }.to_json)

    expect(described_class.fetch_price('ETH', currency: 'brl')).to eq(BigDecimal('11000'))
  end

  it 'returns nil when every API fails' do
    stub_request(:get, /.*/).to_return(status: 503)

    expect(described_class.fetch_price('BTC')).to be_nil
  end
end
