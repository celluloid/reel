module Reel
  class RequestInfo < Struct.new(:http_method, :url, :http_version, :headers)
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
