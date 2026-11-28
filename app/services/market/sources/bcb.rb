module Market
  module Sources
    # Brazilian rates from the Central Bank's SGS time series (api.bcb.gov.br): free, no key.
    module Bcb
      URL = "https://api.bcb.gov.br/dados/serie/bcdata.sgs.%<series>d/dados/ultimos/1?formato=json".freeze
      TTL = 6.hours

      # Rate key → SGS series: Selic target (% a year), CDI (% a year), IPCA over 12 months (%).
      SERIES = { "selic" => 432, "cdi" => 4389, "ipca" => 13_522 }.freeze

      # @return [Quote]
      def self.quote(key)
        series = SERIES.fetch(key)
        body = Market.cached("bcb:#{series}", ttl: TTL) { Http.get_json(format(URL, series: series)) }
        row = Array(body).last
        raise SourceError, "BCB series #{series} came back empty" unless row.is_a?(Hash) && row["valor"]

        Quote.new(key: key, price: BigDecimal(row["valor"].to_s), currency: nil, unit: "percent",
                  as_of: parse_date(row["data"]), source: "Banco Central")
      end

      def self.parse_date(text)
        Date.strptime(text.to_s, "%d/%m/%Y")
      rescue Date::Error
        nil
      end
    end
  end
end
