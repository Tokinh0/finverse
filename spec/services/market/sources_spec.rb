require "rails_helper"

RSpec.describe "Market sources" do
  describe Market::Sources::AwesomeApi do
    it "returns each currency's price in BRL with its change" do
      stub_awesomeapi

      quotes = described_class.quotes(%w[USD EUR])

      expect(quotes["USD"]).to have_attributes(key: "usd", price: BigDecimal("5.50"), currency: "BRL",
                                               change_pct: BigDecimal("-1.2"), source: "AwesomeAPI")
      expect(quotes["EUR"].price).to eq(BigDecimal("6.00"))
    end

    it "raises SourceError when the API fails, and caches the failure briefly" do
      stub = stub_request(:get, /awesomeapi/).to_return(status: 503)

      2.times { expect { described_class.quotes(%w[USD]) }.to raise_error(Market::SourceError) }
      expect(stub).to have_been_requested.once
    end

    it "caches answers" do
      stub = stub_awesomeapi

      2.times { described_class.quotes(%w[USD EUR]) }

      expect(stub).to have_been_requested.once
    end
  end

  describe Market::Sources::CoinGecko do
    it "maps tickers to CoinGecko ids and returns BRL and USD quotes" do
      stub_coingecko({ "bitcoin" => [ 330_000, 60_000 ], "ripple" => [ 5.25, 0.95 ] })

      quotes = described_class.quotes(%w[btc XRP])

      expect(quotes.dig("BTC", "BRL")).to have_attributes(price: BigDecimal("330000"), currency: "BRL", change_pct: BigDecimal("-4.5"))
      expect(quotes.dig("XRP", "USD").price).to eq(BigDecimal("0.95"))
      expect(a_request(:get, /coingecko/).with(query: hash_including(ids: "bitcoin,ripple"))).to have_been_made
    end

    it "leaves out tickers CoinGecko doesn't know" do
      stub_coingecko({ "bitcoin" => [ 1, 1 ] })

      expect(described_class.quotes(%w[BTC NOPE]).keys).to eq(%w[BTC])
    end
  end

  describe Market::Sources::Bcb do
    it "returns the latest value of a rate series" do
      stub_bcb("13.65")

      quote = described_class.quote("cdi")

      expect(quote).to have_attributes(key: "cdi", price: BigDecimal("13.65"), unit: "percent", as_of: Date.new(2026, 11, 26))
      expect(a_request(:get, %r{bcdata\.sgs\.4389/})).to have_been_made
    end

    it "raises SourceError on an empty series" do
      stub_request(:get, /bcb/).to_return(body: "[]")

      expect { described_class.quote("selic") }.to raise_error(Market::SourceError)
    end
  end

  describe Market::Sources::Brapi do
    it "needs a token" do
      expect(described_class).not_to be_configured
      expect { described_class.quote("WEGE3") }.to raise_error(Market::MissingToken)
    end

    it "uses the token from settings, or from BRAPI_TOKEN" do
      configure_brapi("from-settings")
      expect(described_class.token).to eq("from-settings")

      AppSetting.current.update!(brapi_token: nil)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("BRAPI_TOKEN").and_return("from-env")
      expect(described_class.token).to eq("from-env")
    end

    it "returns the quote, sending the token as a bearer header" do
      configure_brapi
      stub_brapi("WEGE3", price: 42.1)

      quote = described_class.quote("wege3")

      expect(quote).to have_attributes(key: "wege3", price: BigDecimal("42.1"), currency: "BRL", change_pct: BigDecimal("1.5"))
      expect(a_request(:get, "https://brapi.dev/api/quote/WEGE3").with(headers: { "Authorization" => "Bearer brapi-test-token-9876" }))
        .to have_been_made
    end

    it "returns nil for a ticker brapi doesn't know" do
      configure_brapi
      stub_brapi("NOPE3", price: nil, status: 404)

      expect(described_class.quote("NOPE3")).to be_nil
    end

    it "raises SourceError when the token is rejected" do
      configure_brapi
      stub_brapi("WEGE3", price: nil, status: 401)

      expect { described_class.quote("WEGE3") }.to raise_error(Market::SourceError)
    end
  end
end
