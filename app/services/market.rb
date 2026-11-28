# Market data: quotes from free public sources, used by the Market page and to value assets.
#
# Responses are cached in this process (Market.cache) so a page load doesn't hit the sources
# every time, and failures are cached briefly so a down source isn't asked again on each request.
module Market
  # A source couldn't answer (network error, HTTP error, unexpected body). The message is for logs.
  class SourceError < StandardError; end
  # The source needs a token that isn't configured.
  class MissingToken < SourceError; end

  # One price. `change_pct` is the change against the previous close (24h for crypto).
  # `unit` is "currency" for prices and "percent" for rates.
  Quote = Struct.new(:key, :price, :currency, :change_pct, :as_of, :source, :unit, keyword_init: true) do
    def as_json(*)
      {
        key: key,
        price: price&.to_f,
        currency: currency,
        change_pct: change_pct&.to_f&.round(2),
        as_of: as_of&.iso8601,
        source: source,
        unit: unit || "currency"
      }
    end
  end

  FAILURE_TTL = 1.minute

  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new(size: 8.megabytes)
  end

  # Caches the block's result for `ttl`; a SourceError is cached for FAILURE_TTL and re-raised.
  def self.cached(key, ttl:)
    hit = cache.read(key)
    raise SourceError, hit[:error] if hit.is_a?(Hash) && hit.key?(:error)
    return hit unless hit.nil?

    value = yield
    cache.write(key, value, expires_in: ttl)
    value
  rescue MissingToken
    raise
  rescue SourceError => e
    cache.write(key, { error: e.message }, expires_in: FAILURE_TTL) unless hit
    raise
  end
end
