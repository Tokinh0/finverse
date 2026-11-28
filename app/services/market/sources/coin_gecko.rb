module Market
  module Sources
    # Crypto prices from CoinGecko's public API: free, no key, rate-limited (hence the cache).
    module CoinGecko
      URL = "https://api.coingecko.com/api/v3/simple/price".freeze
      TTL = 5.minutes

      # Tickers people type → CoinGecko coin ids. Anything else is tried as a lowercase id.
      IDS = {
        "BTC" => "bitcoin", "ETH" => "ethereum", "XRP" => "ripple", "SOL" => "solana",
        "USDT" => "tether", "USDC" => "usd-coin", "BNB" => "binancecoin", "ADA" => "cardano",
        "DOGE" => "dogecoin", "DOT" => "polkadot", "AVAX" => "avalanche-2", "LINK" => "chainlink",
        "LTC" => "litecoin", "BCH" => "bitcoin-cash", "XLM" => "stellar", "TRX" => "tron",
        "ATOM" => "cosmos", "UNI" => "uniswap", "NEAR" => "near", "POL" => "polygon-ecosystem-token",
        "MATIC" => "matic-network", "TON" => "the-open-network", "SHIB" => "shiba-inu", "XMR" => "monero"
      }.freeze

      def self.id_for(ticker)
        IDS[ticker.to_s.strip.upcase] || ticker.to_s.strip.downcase
      end

      # @param tickers [Array<String>]
      # @return [Hash{String => Hash{String => Quote}}] ticker (upcased) → { "BRL" => Quote, "USD" => Quote };
      #   tickers CoinGecko doesn't know are left out
      def self.quotes(tickers)
        ids = tickers.to_h { |ticker| [ ticker.to_s.strip.upcase, id_for(ticker) ] }
        body = fetch(ids.values.uniq.sort)

        ids.each_with_object({}) do |(ticker, id), quotes|
          row = body[id]
          next unless row.is_a?(Hash) && row["brl"]

          as_of = row["last_updated_at"] && Time.zone.at(row["last_updated_at"].to_i)
          quotes[ticker] = %w[brl usd].filter_map { |currency|
            next unless row[currency]

            [ currency.upcase, Quote.new(key: ticker.downcase, price: BigDecimal(row[currency].to_s), currency: currency.upcase,
                                         change_pct: row["#{currency}_24h_change"] && BigDecimal(row["#{currency}_24h_change"].to_s),
                                         as_of: as_of, source: "CoinGecko") ]
          }.to_h
        end
      end

      def self.fetch(ids)
        Market.cached("coingecko:#{ids.join(',')}", ttl: TTL) do
          query = URI.encode_www_form(ids: ids.join(","), vs_currencies: "brl,usd",
                                      include_24hr_change: true, include_last_updated_at: true)
          Http.get_json("#{URL}?#{query}")
        end
      end
    end
  end
end
