module Market
  # Looks up today's price of each of the profile's assets and compares it with the value saved
  # on the asset. Nothing is saved here; `Market::AssetValuation#apply!` saves on request.
  #
  # Where the price comes from, by asset type:
  # - criptomoedas: CoinGecko by ticker, then brapi (crypto ETFs listed on B3, like a "…11" ticker)
  # - B3 types (ações nacionais, FIIs, renda variável): brapi
  # - ações internacionais, REITs: brapi too (it lists some US tickers); USD prices become BRL
  # - renda fixa, reserva: no market price; they keep the saved value ("manual")
  #
  # Each row's status: "priced", "not_found" (no source knows the ticker), "manual", "no_ticker",
  # "no_quantity", "needs_token" (brapi needed but not set up) or "unavailable" (the source failed).
  class AssetValuation
    CRYPTO_TYPES = %w[criptomoedas].freeze
    EXCHANGE_TYPES = %w[acoes_nacionais fundos_imobiliarios renda_variavel acoes_internacionais reits].freeze

    Row = Struct.new(:asset, :status, :quote, :unit_price, keyword_init: true) do
      def live_value
        unit_price && asset.quantity && (unit_price * BigDecimal(asset.quantity.to_s))
      end

      def as_json(*)
        {
          id: asset.id, ticker: asset.ticker, description: asset.description,
          asset_type: asset.asset_type,
          asset_type_label: Asset::ASSET_TYPES[asset.asset_type],
          quantity: asset.quantity,
          saved_unit_price: asset.last_uploaded_unit_value&.to_f,
          saved_value: asset.current_value&.to_f,
          status: status,
          unit_price: unit_price&.to_f,
          live_value: live_value&.to_f&.round(2),
          quote_currency: quote&.currency,
          change_pct: quote&.change_pct&.to_f&.round(2),
          as_of: quote&.as_of&.iso8601,
          source: quote&.source
        }
      end
    end

    def initialize(assets = Asset.order(:id))
      @assets = assets.to_a
    end

    def rows
      @rows ||= begin
        crypto_quotes = crypto_quotes()
        @assets.map { |asset| row_for(asset, crypto_quotes) }
      end
    end

    def as_json(*)
      priced = rows.select { |row| row.status == "priced" }
      {
        assets: rows.map(&:as_json),
        totals: {
          priced_count: priced.size,
          saved_value: priced.sum { |row| row.asset.current_value || 0 }.to_f.round(2),
          live_value: priced.sum(&:live_value).to_f.round(2)
        },
        brapi_configured: Sources::Brapi.configured?,
        usd_brl: usd_brl&.to_f
      }
    end

    # Saves the live price on the priced assets (all, or only `ids`): the unit price and the
    # value (unit price × quantity).
    # @return [Array<Asset>] the assets that changed
    def apply!(ids: nil)
      wanted = ids&.map(&:to_i)
      targets = rows.select { |row| row.status == "priced" && (wanted.nil? || wanted.include?(row.asset.id)) }

      Asset.transaction do
        targets.each do |row|
          row.asset.update!(last_uploaded_unit_value: row.unit_price, current_value: row.live_value.round(2))
        end
      end
      targets.map(&:asset)
    end

    private

    def row_for(asset, crypto_quotes)
      return Row.new(asset: asset, status: "manual") unless priceable?(asset)
      return Row.new(asset: asset, status: "no_ticker") if asset.ticker.blank?
      return Row.new(asset: asset, status: "no_quantity") unless asset.quantity.to_f.positive?

      quote = crypto_quotes&.dig(asset.ticker.strip.upcase, "BRL") if crypto?(asset)
      quote ||= Sources::Brapi.quote(asset.ticker)
      return Row.new(asset: asset, status: "not_found") unless quote

      priced(asset, quote)
    rescue MissingToken
      # Crypto only reaches brapi when CoinGecko didn't have it (or was down).
      status = if !crypto?(asset) then "needs_token" elsif crypto_quotes.nil? then "unavailable" else "not_found" end
      Row.new(asset: asset, status: status)
    rescue SourceError => e
      Rails.logger.warn("[market] #{asset.ticker}: #{e.message}")
      Row.new(asset: asset, status: "unavailable")
    end

    def priced(asset, quote)
      unit_price = to_brl(quote)
      return Row.new(asset: asset, status: "unavailable", quote: quote) unless unit_price

      Row.new(asset: asset, status: "priced", quote: quote, unit_price: unit_price)
    end

    def to_brl(quote)
      return quote.price if quote.currency.blank? || quote.currency == "BRL"
      return quote.price * usd_brl if quote.currency == "USD" && usd_brl

      nil
    end

    def usd_brl
      return @usd_brl if defined?(@usd_brl)

      @usd_brl = Sources::AwesomeApi.quotes(%w[USD])["USD"]&.price
    rescue SourceError
      @usd_brl = nil
    end

    # One CoinGecko call for every crypto ticker; nil when CoinGecko is down (brapi is tried next).
    def crypto_quotes
      tickers = @assets.select { |asset| crypto?(asset) && asset.ticker.present? }.map(&:ticker)
      return {} if tickers.empty?

      Sources::CoinGecko.quotes(tickers)
    rescue SourceError => e
      Rails.logger.warn("[market] #{e.message}")
      nil
    end

    def crypto?(asset)
      CRYPTO_TYPES.include?(type_key(asset))
    end

    def priceable?(asset)
      crypto?(asset) || EXCHANGE_TYPES.include?(type_key(asset))
    end

    def type_key(asset)
      asset.asset_type
    end
  end
end
