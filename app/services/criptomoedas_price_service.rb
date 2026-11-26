# app/services/criptomoedas_price_service.rb
class CriptomoedasPriceService
  require 'net/http'
  require 'json'
  require 'uri'

  class << self
    # Fetches the current price for a cryptocurrency ticker
    # @param ticker [String] The cryptocurrency ticker symbol (e.g., 'BTC', 'ETH', 'USDT')
    # @param currency [String] The target currency ('usd' or 'brl'), defaults to 'usd'
    # @return [BigDecimal, nil] The current price in the specified currency, or nil if all APIs fail
    def fetch_price(ticker, currency: 'usd')
      # Try CoinGecko first (free, no API key required)
      price = fetch_from_coingecko(ticker, currency: currency)
      return price if price

      # Fallback to CoinCap (only supports USD, will convert if needed)
      price = fetch_from_coincap(ticker, currency: currency)
      return price if price

      # Both APIs failed
      Rails.logger.warn("Failed to fetch price for #{ticker} from all APIs")
      nil
    end


    private

    # Fetches price from CoinGecko API
    # @param ticker [String] The cryptocurrency ticker
    # @param currency [String] The target currency ('usd' or 'brl')
    # @return [BigDecimal, nil] The price or nil if failed
    def fetch_from_coingecko(ticker, currency: 'usd')
      # Map common tickers to CoinGecko IDs
      coin_id = coingecko_id(ticker)
      return nil unless coin_id

      uri = URI("https://api.coingecko.com/api/v3/simple/price")
      params = {
        ids: coin_id,
        vs_currencies: currency
      }
      uri.query = URI.encode_www_form(params)

      response = make_request(uri)
      return nil unless response

      price = response.dig(coin_id, currency)
      return nil unless price

      BigDecimal(price.to_s)
    rescue => e
      Rails.logger.error("CoinGecko API error for #{ticker}: #{e.message}")
      nil
    end

    # Fetches price from CoinCap API (only supports USD, converts to BRL if needed)
    # @param ticker [String] The cryptocurrency ticker
    # @param currency [String] The target currency ('usd' or 'brl')
    # @return [BigDecimal, nil] The price or nil if failed
    def fetch_from_coincap(ticker, currency: 'usd')
      uri = URI("https://api.coincap.io/v2/assets/#{ticker.upcase}")

      response = make_request(uri)
      return nil unless response

      price_usd = response.dig('data', 'priceUsd')
      return nil unless price_usd

      price = BigDecimal(price_usd.to_s)
      
      # Convert to BRL if needed
      if currency == 'brl'
        usd_to_brl_rate = fetch_usd_to_brl_rate
        return nil unless usd_to_brl_rate
        price = price * usd_to_brl_rate
      end
      
      price
    rescue => e
      Rails.logger.error("CoinCap API error for #{ticker}: #{e.message}")
      nil
    end

    # Fetches USD to BRL exchange rate
    # Uses CoinGecko's exchange_rates endpoint or a stablecoin as proxy
    # @return [BigDecimal, nil] The exchange rate or nil if failed
    def fetch_usd_to_brl_rate
      # Try using exchange_rates endpoint first
      uri = URI("https://api.coingecko.com/api/v3/exchange_rates")
      response = make_request(uri)
      
      if response && response.dig('rates', 'brl', 'value')
        rate = response.dig('rates', 'brl', 'value')
        return BigDecimal(rate.to_s)
      end

      # Fallback: Use USDC as proxy (1 USDC ≈ 1 USD)
      uri = URI("https://api.coingecko.com/api/v3/simple/price")
      params = {
        ids: 'usd-coin',
        vs_currencies: 'brl'
      }
      uri.query = URI.encode_www_form(params)

      response = make_request(uri)
      return nil unless response

      rate = response.dig('usd-coin', 'brl')
      return nil unless rate

      BigDecimal(rate.to_s)
    rescue => e
      Rails.logger.error("Failed to fetch USD to BRL rate: #{e.message}")
      nil
    end

    # Makes an HTTP GET request
    # @param uri [URI] The URI to request
    # @return [Hash, nil] The parsed JSON response or nil if failed
    def make_request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      http.open_timeout = 10

      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'application/json'

      response = http.request(request)

      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue => e
      Rails.logger.error("HTTP request error: #{e.message}")
      nil
    end

    # Maps ticker symbols to CoinGecko coin IDs
    # @param ticker [String] The ticker symbol
    # @return [String, nil] The CoinGecko ID or nil if not found
    def coingecko_id(ticker)
      mapping = {
        'BTC' => 'bitcoin',
        'ETH' => 'ethereum',
        'USDT' => 'tether',
        'BNB' => 'binancecoin',
        'SOL' => 'solana',
        'USDC' => 'usd-coin',
        'XRP' => 'ripple',
        'ADA' => 'cardano',
        'DOGE' => 'dogecoin',
        'DOT' => 'polkadot',
        'MATIC' => 'matic-network',
        'AVAX' => 'avalanche-2',
        'LINK' => 'chainlink',
        'UNI' => 'uniswap',
        'ATOM' => 'cosmos',
        'ETC' => 'ethereum-classic',
        'LTC' => 'litecoin',
        'BCH' => 'bitcoin-cash',
        'XLM' => 'stellar',
        'ALGO' => 'algorand',
        'VET' => 'vechain',
        'ICP' => 'internet-computer',
        'FIL' => 'filecoin',
        'TRX' => 'tron',
        'EOS' => 'eos',
        'AAVE' => 'aave',
        'MKR' => 'maker',
        'COMP' => 'compound-governance-token',
        'SUSHI' => 'sushi',
        'YFI' => 'yearn-finance',
        'SNX' => 'havven',
        'CRV' => 'curve-dao-token',
        '1INCH' => '1inch',
        'BAL' => 'balancer',
        'ZRX' => '0x',
        'ENJ' => 'enjincoin',
        'MANA' => 'decentraland',
        'SAND' => 'the-sandbox',
        'AXS' => 'axie-infinity',
        'GALA' => 'gala',
        'THETA' => 'theta-token',
        'FLOW' => 'flow',
        'NEAR' => 'near',
        'FTM' => 'fantom',
        'HBAR' => 'hedera-hashgraph',
        'EGLD' => 'elrond-erd-2',
        'ZIL' => 'zilliqa',
        'IOTA' => 'iota',
        'WAVES' => 'waves',
        'XTZ' => 'tezos',
        'ZEC' => 'zcash',
        'DASH' => 'dash',
        'XMR' => 'monero',
        'GRT' => 'the-graph',
        'BAT' => 'basic-attention-token',
        'ZEN' => 'zencash',
        'ONT' => 'ontology',
        'QTUM' => 'qtum',
        'NEO' => 'neo',
        'OMG' => 'omisego',
        'KNC' => 'kyber-network-crystal',
        'REN' => 'republic-protocol',
        'STORJ' => 'storj',
        'SKL' => 'skale',
        'ANKR' => 'ankr',
        'OCEAN' => 'ocean-protocol',
        'BAND' => 'band-protocol',
        'NMR' => 'numeraire',
        'COTI' => 'coti',
        'POLY' => 'polymath',
        'FET' => 'fetch-ai',
        'CELR' => 'celer-network',
        'PHB' => 'phoenix-global',
        'ONE' => 'harmony'
      }

      mapping[ticker.upcase] || ticker.downcase
    end
  end
end

