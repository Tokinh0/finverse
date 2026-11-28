require "rails_helper"

RSpec.describe Market::Overview do
  before do
    stub_awesomeapi
    stub_coingecko({ "bitcoin" => [ 330_000, 60_000 ], "ethereum" => [ 9_200, 1_650 ], "ripple" => [ 5.25, 0.95 ], "solana" => [ 396, 71 ] })
    stub_bcb
  end

  def group(result, key) = result[:groups].find { |g| g[:key] == key }[:quotes]

  it "returns currencies, crypto and Brazilian indicators" do
    result = described_class.call

    expect(group(result, "currencies").pluck(:key)).to eq(%w[usd eur])
    expect(group(result, "crypto").first).to include(key: "btc", price: 330_000.0, price_usd: 60_000.0, change_pct: -4.5)
    expect(group(result, "brazil").pluck(:key)).to eq(%w[ibovespa selic cdi ipca])
    expect(group(result, "brazil").last).to include(price: 13.75, unit: "percent", as_of: "2026-11-26")
  end

  it "asks for a brapi token for the Ibovespa, and shows it once there is one" do
    expect(group(described_class.call, "brazil").first).to eq(key: "ibovespa", error: "needs_token")

    configure_brapi
    stub_brapi("^BVSP", price: 128_000)
    Market.cache.clear

    result = described_class.call
    expect(result[:brapi_configured]).to be(true)
    expect(group(result, "brazil").first).to include(key: "ibovespa", price: 128_000.0)
  end

  it "marks only the failing source's quotes as unavailable" do
    stub_request(:get, /coingecko/).to_return(status: 429)

    result = described_class.call

    expect(group(result, "crypto")).to all(include(error: "unavailable"))
    expect(group(result, "currencies").first).to include(price: 5.5)
  end
end
