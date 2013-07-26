module Reel
  class RequestInfo
    attr_reader :http_method, :url, :http_version, :headers

    def initialize(http_method, url, http_version, headers)
      @http_method  = http_method
      @url          = url
      @http_version = http_version
      @headers      = headers
    end

    UPGRADE   = 'Upgrade'.freeze
    WEBSOCKET = 'websocket'.freeze

    # Array#include? seems slow compared to Hash lookup
    request_methods = Http::METHODS.map { |m| m.to_s.upcase }
    REQUEST_METHODS = Hash[request_methods.zip(request_methods)].freeze

    def method
      REQUEST_METHODS[http_method]
    end

    def websocket_request?
      headers[UPGRADE] && headers[UPGRADE].downcase == WEBSOCKET
    end
  end
end
