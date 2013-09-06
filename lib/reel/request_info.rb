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

    def websocket_request?
      headers[UPGRADE] && headers[UPGRADE].downcase == WEBSOCKET
    end
  end
end
