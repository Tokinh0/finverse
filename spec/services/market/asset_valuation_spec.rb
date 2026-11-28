require "rails_helper"

RSpec.describe Market::AssetValuation do
  before do
    stub_awesomeapi({ "USD" => "5.00" })
    stub_coingecko({ "bitcoin" => [ 300_000, 60_000 ] })
  end

  let!(:btc) { create(:asset, asset_type: "criptomoedas", ticker: "BTC", quantity: 0.5, current_value: 100_000, last_uploaded_unit_value: 200_000) }
  let!(:tesouro) { create(:asset, asset_type: "renda_fixa", ticker: "LTN", quantity: 1, current_value: 5_000) }

  def row(result, asset) = result[:assets].find { |a| a[:id] == asset.id }

  it "prices crypto by ticker and keeps fixed income manual" do
    result = described_class.new.as_json

    expect(row(result, btc)).to include(status: "priced", unit_price: 300_000.0, live_value: 150_000.0,
                                        saved_value: 100_000.0, saved_unit_price: 200_000.0, source: "CoinGecko")
    expect(row(result, tesouro)).to include(status: "manual", unit_price: nil)
    expect(result[:totals]).to eq(priced_count: 1, saved_value: 100_000.0, live_value: 150_000.0)
  end

  it "needs a brapi token for B3 tickers, then prices them" do
    stock = create(:asset, asset_type: "acoes_nacionais", ticker: "WEGE3", quantity: 10)
    expect(row(described_class.new.as_json, stock)).to include(status: "needs_token")

    configure_brapi
    stub_brapi("WEGE3", price: 42.5)
    expect(row(described_class.new.as_json, stock)).to include(status: "priced", live_value: 425.0, change_pct: 1.5)
  end

  it "converts USD quotes to BRL" do
    configure_brapi
    stub_brapi("VOO", price: 500, currency: "USD")
    etf = create(:asset, asset_type: "acoes_internacionais", ticker: "VOO", quantity: 2)

    expect(row(described_class.new.as_json, etf)).to include(status: "priced", unit_price: 2_500.0, live_value: 5_000.0, quote_currency: "USD")
  end

  it "tries brapi for crypto tickers CoinGecko doesn't know, like B3 crypto ETFs" do
    configure_brapi
    stub_brapi("HASH11", price: 50)
    etf = create(:asset, asset_type: "criptomoedas", ticker: "HASH11", quantity: 4)

    expect(row(described_class.new.as_json, etf)).to include(status: "priced", live_value: 200.0, source: "brapi.dev")
  end

  it "explains why an asset has no price" do
    no_ticker = create(:asset, asset_type: "acoes_nacionais", ticker: "", quantity: 1)
    no_quantity = create(:asset, asset_type: "criptomoedas", ticker: "BTC", quantity: 0)
    unknown = create(:asset, asset_type: "criptomoedas", ticker: "NOPE", quantity: 1)
    result = described_class.new.as_json

    expect(row(result, no_ticker)[:status]).to eq("no_ticker")
    expect(row(result, no_quantity)[:status]).to eq("no_quantity")
    expect(row(result, unknown)[:status]).to eq("not_found")
  end

  it "marks assets unavailable when their source fails" do
    stub_request(:get, /coingecko/).to_return(status: 500)

    expect(row(described_class.new.as_json, btc)[:status]).to eq("unavailable")
  end

  describe "#apply!" do
    it "saves the live unit price and value on priced assets only" do
      updated = described_class.new.apply!

      expect(updated).to eq([ btc ])
      expect(btc.reload).to have_attributes(last_uploaded_unit_value: BigDecimal("300000"), current_value: BigDecimal("150000"))
      expect(tesouro.reload.current_value).to eq(BigDecimal("5000"))
    end

    it "keeps small unit prices exact" do
      stub_coingecko({ "bitcoin" => [ 300_000, 60_000 ], "dogecoin" => [ 0.31684812, 0.06 ] })
      doge = create(:asset, asset_type: "criptomoedas", ticker: "DOGE", quantity: 1000)

      described_class.new.apply!(ids: [ doge.id ])

      expect(doge.reload).to have_attributes(last_uploaded_unit_value: BigDecimal("0.31684812"), current_value: BigDecimal("316.85"))
    end

    it "only updates the given assets" do
      described_class.new.apply!(ids: [ tesouro.id ])

      expect(btc.reload.current_value).to eq(BigDecimal("100000"))
    end
  end
end
