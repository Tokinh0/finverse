module Market
  module Sources
    # Exchange rates against the real from AwesomeAPI (economia.awesomeapi.com.br): free, no key.
    module AwesomeApi
      URL = "https://economia.awesomeapi.com.br/json/last/".freeze
      TTL = 5.minutes

      # @param codes [Array<String>] currency codes, e.g. %w[USD EUR]
      # @return [Hash{String => Quote}] by code, in BRL
      def self.quotes(codes)
        pairs = codes.map { |code| "#{code}-BRL" }
        body = Market.cached("awesomeapi:#{pairs.join(',')}", ttl: TTL) { Http.get_json(URL + pairs.join(",")) }

        codes.each_with_object({}) do |code, quotes|
          row = body["#{code}BRL"]
          next unless row.is_a?(Hash) && row["bid"]

          quotes[code] = Quote.new(
            key: code.downcase, price: BigDecimal(row["bid"].to_s), currency: "BRL",
            change_pct: row["pctChange"] && BigDecimal(row["pctChange"].to_s),
            as_of: row["timestamp"] && Time.zone.at(row["timestamp"].to_i), source: "AwesomeAPI"
          )
        end
      end
    end
  end
end
