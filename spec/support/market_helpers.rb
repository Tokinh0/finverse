# Stubs for the market data sources. Market.cache is cleared before every example so stubs
# from one example never answer another.
module MarketHelpers
  def stub_awesomeapi(rates = { "USD" => "5.50", "EUR" => "6.00" }, change: "-1.2")
    body = rates.to_h { |code, bid| [ "#{code}BRL", { bid: bid, pctChange: change, timestamp: "1795815319" } ] }
    stub_request(:get, %r{economia\.awesomeapi\.com\.br/json/last/}).to_return(body: body.to_json)
  end

  def stub_coingecko(prices = { "bitcoin" => [ 330_000, 60_000 ] })
    body = prices.to_h do |id, (brl, usd)|
      [ id, { brl: brl, usd: usd, brl_24h_change: -4.5, usd_24h_change: -3.0, last_updated_at: 1_795_842_770 } ]
    end
    stub_request(:get, %r{api\.coingecko\.com/api/v3/simple/price}).to_return(body: body.to_json)
  end

  def stub_bcb(value = "13.75")
    stub_request(:get, %r{api\.bcb\.gov\.br/dados/serie/}).to_return(body: [ { data: "26/11/2026", valor: value } ].to_json)
  end

  def stub_brapi(symbol, price:, currency: "BRL", change: 1.5, status: 200)
    body = status == 200 ? { results: [ { symbol: symbol, currency: currency, regularMarketPrice: price,
                                          regularMarketChangePercent: change,
                                          regularMarketTime: "2026-11-27T20:00:00.000Z" } ] } : { error: true }
    stub_request(:get, "https://brapi.dev/api/quote/#{ERB::Util.url_encode(symbol)}").to_return(status: status, body: body.to_json)
  end

  def configure_brapi(token = "brapi-test-token-9876")
    AppSetting.current.update!(brapi_token: token)
  end
end

RSpec.configure do |config|
  config.include MarketHelpers
  config.before { Market.cache.clear }
end
