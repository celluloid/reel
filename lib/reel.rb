require 'uri'

require 'http/parser'
require 'http'
require 'celluloid/io'

require 'reel/version'
require 'reel/mixins'
require 'reel/connection'
require 'reel/logger'
require 'reel/request'
require 'reel/response'

require 'reel/server'
require 'reel/server/http'
require 'reel/server/https'

require 'reel/websocket'
require 'reel/stream'

# A Reel good HTTP server
module Reel
  # Error reading a request
  class RequestError < StandardError; end

  # Error occurred performing IO on a socket
  class SocketError < RequestError; end

  # Error occurred when trying to use the socket after it was upgraded
  class SocketUpgradedError < NilClass
    def self.method_missing(m, *)
      raise(Reel::RequestError, 'Reel::Connection#socket can not be used anymore as it was upgraded. Use Reel::WebSocket instance instead.')
    end
  end

  # Error occured during a WebSockets handshake
  class HandshakeError < RequestError; end

  # The method given was not understood
  class UnsupportedMethodError < ArgumentError; end

  # wrong state for a given operation
  class StateError < RuntimeError; end
end
