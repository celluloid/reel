module Reel
  class Request
    class Info

      CASE_INSENSITVE_HASH = Hash.new do |hash, key|
        hash[hash.keys.find {|k| k =~ /#{key}/i}] if key
      end

      attr_reader :http_method, :url, :http_version, :headers

      def initialize(http_method, url, http_version, headers)
        @http_method  = http_method
        @url          = url
        @http_version = http_version
        @headers      = CASE_INSENSITVE_HASH.merge headers
      end

      UPGRADE   = 'Upgrade'.freeze
      WEBSOCKET = 'websocket'.freeze

      def websocket_request?
        headers[UPGRADE] && headers[UPGRADE].downcase == WEBSOCKET
      end
    end
  end
end
