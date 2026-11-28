module Market
  module Sources
    # B3 quotes (stocks, FIIs, ETFs, BDRs and the Ibovespa) from brapi.dev. It needs a token
    # (free plan available), saved in Settings for the account; BRAPI_TOKEN in the environment
    # works too. The free plan allows one ticker per request, so tickers are fetched one by one.
    module Brapi
      URL = "https://brapi.dev/api/quote/".freeze
      TTL = 15.minutes

      def self.token
        AppSetting.current.brapi_token.presence || ENV["BRAPI_TOKEN"].presence
      end

      def self.configured?
        token.present?
      end

      # @return [Quote, nil] nil when brapi doesn't know the ticker
      def self.quote(ticker, key: ticker.downcase)
        secret = token
        raise MissingToken, "brapi token missing" unless secret

        symbol = ticker.to_s.strip.upcase
        body = Market.cached("brapi:#{symbol}:#{Digest::SHA256.hexdigest(secret).first(8)}", ttl: TTL) do
          fetch(symbol, secret)
        end
        row = Array(body["results"]).first
        return nil unless row.is_a?(Hash) && row["regularMarketPrice"]

        Quote.new(key: key, price: BigDecimal(row["regularMarketPrice"].to_s), currency: row["currency"].presence || "BRL",
                  change_pct: row["regularMarketChangePercent"] && BigDecimal(row["regularMarketChangePercent"].to_s),
                  as_of: row["regularMarketTime"] && Time.zone.parse(row["regularMarketTime"].to_s), source: "brapi.dev")
      end

      # An unknown ticker is a 404 with a JSON body: that's "not found", not a failure.
      def self.fetch(symbol, secret)
        Http.get_json(URL + ERB::Util.url_encode(symbol), headers: { "Authorization" => "Bearer #{secret}" })
      rescue SourceError => e
        raise unless e.message.include?("answered 404")

        { "results" => [] }
      end
    end
  end
end
