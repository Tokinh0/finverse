require "net/http"

module Market
  # GET a JSON document, with short timeouts. Raises SourceError for anything but a 2xx JSON body.
  module Http
    TIMEOUT = 8

    def self.get_json(url, headers: {})
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["User-Agent"] = "Finverse"
      headers.each { |name, value| request[name] = value }

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                 open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.request(request) }
      raise SourceError, "#{uri.host} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
      raise SourceError, "#{uri&.host}: #{e.class}: #{e.message}"
    end
  end
end
