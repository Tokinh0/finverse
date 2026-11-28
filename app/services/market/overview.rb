module Market
  # The Market page's indicators, grouped. Each source is asked once; one that fails only marks its
  # own quotes as unavailable, so the rest of the page still shows.
  #
  #   { groups: [ { key: "currencies", quotes: [ { key: "usd", price: 5.55, ... } ] }, ... ],
  #     brapi_configured: true, generated_at: "..." }
  #
  # A quote that couldn't be loaded comes as { key:, error: "unavailable" | "needs_token" }.
  class Overview
    CURRENCIES = %w[USD EUR].freeze
    CRYPTO = %w[BTC ETH XRP SOL].freeze
    RATES = %w[selic cdi ipca].freeze

    def self.call
      new.call
    end

    def call
      {
        groups: [
          { key: "currencies", quotes: currencies },
          { key: "crypto", quotes: crypto },
          { key: "brazil", quotes: [ ibovespa ] + rates }
        ],
        brapi_configured: Sources::Brapi.configured?,
        generated_at: Time.current.iso8601
      }
    end

    private

    def currencies
      quotes = Sources::AwesomeApi.quotes(CURRENCIES)
      CURRENCIES.map { |code| quotes[code]&.as_json || unavailable(code.downcase) }
    rescue SourceError => e
      log(e)
      CURRENCIES.map { |code| unavailable(code.downcase) }
    end

    # Price in BRL, with the USD price alongside.
    def crypto
      quotes = Sources::CoinGecko.quotes(CRYPTO)
      CRYPTO.map do |ticker|
        brl, usd = quotes.dig(ticker, "BRL"), quotes.dig(ticker, "USD")
        next unavailable(ticker.downcase) unless brl

        brl.as_json.merge(price_usd: usd&.price&.to_f, change_pct_usd: usd&.change_pct&.to_f&.round(2))
      end
    rescue SourceError => e
      log(e)
      CRYPTO.map { |ticker| unavailable(ticker.downcase) }
    end

    def ibovespa
      Sources::Brapi.quote("^BVSP", key: "ibovespa")&.as_json || unavailable("ibovespa")
    rescue MissingToken
      { key: "ibovespa", error: "needs_token" }
    rescue SourceError => e
      log(e)
      unavailable("ibovespa")
    end

    def rates
      RATES.map do |key|
        Sources::Bcb.quote(key).as_json
      rescue SourceError => e
        log(e)
        unavailable(key)
      end
    end

    def unavailable(key)
      { key: key, error: "unavailable" }
    end

    def log(error)
      Rails.logger.warn("[market] #{error.message}")
    end
  end
end
