# app/models/crypto.rb
# Handles cryptocurrency-specific logic for assets
class Crypto
  # Supported cryptocurrency tickers
  SUPPORTED_TICKERS = %w[BTC ETH XRP SOL DOGE].freeze

  attr_reader :asset

  def initialize(asset)
    @asset = asset
  end

  # Updates the asset's price from external APIs
  # Fetches price in BRL and updates last_uploaded_unit_value and current_value
  # @return [Boolean] true if update was successful, false otherwise
  def update_price
    return false unless supported_ticker?
    return false if asset.ticker.blank?
    return false if asset.quantity.nil? || asset.quantity <= 0

    # Fetch price in BRL
    price_brl = CriptomoedasPriceService.fetch_price(asset.ticker, currency: 'brl')

    if price_brl && price_brl > 0
      # Update last_uploaded_unit_value and calculate current_value
      asset.update(
        last_uploaded_unit_value: price_brl,
        current_value: price_brl * asset.quantity
      )
      true
    elsif asset.last_uploaded_unit_value && asset.last_uploaded_unit_value > 0
      # Fallback to last_uploaded_unit_value if API fails
      asset.update(
        current_value: asset.last_uploaded_unit_value * asset.quantity
      )
      true
    else
      Rails.logger.error("No price available for #{asset.ticker} and no last_uploaded_unit_value")
      false
    end
  end

  # Checks if the asset's ticker is supported
  # @return [Boolean]
  def supported_ticker?
    return false if asset.ticker.blank?
    SUPPORTED_TICKERS.include?(asset.ticker.upcase)
  end

  # Class method to update all supported crypto assets
  # @return [Integer] Number of assets successfully updated
  def self.update_all_prices
    assets = Asset.criptomoedas.where(ticker: SUPPORTED_TICKERS)
    count = 0

    assets.find_each do |asset|
      crypto = new(asset)
      count += 1 if crypto.update_price
    end

    count
  end

  # Class method to create a Crypto instance for an asset
  # @param asset [Asset] The asset to wrap
  # @return [Crypto, nil] Crypto instance if asset is a crypto asset, nil otherwise
  def self.for(asset)
    return nil unless asset.criptomoedas?
    new(asset)
  end
end

