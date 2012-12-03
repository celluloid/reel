require 'uri'

require 'http/parser'
require 'http'
require 'celluloid/io'

require 'reel/version'

require 'reel/mixins'

require 'reel/connection'
require 'reel/logger'
require 'reel/request'
require 'reel/request_parser'
require 'reel/response'
require 'reel/server'
require 'reel/websocket'
require 'reel/stream'

require 'rack'
require 'rack/handler'
require 'rack/handler/reel'
require 'reel/rack_worker'

# A Reel good HTTP server
module Reel

  # Error reading a request
  class RequestError < StandardError; end

  # Error occured performing IO on a socket
  class SocketError < RequestError; end

  # Error occured during a WebSockets handshake
  class HandshakeError < RequestError; end

  # The method given was not understood
  class UnsupportedMethodError < ArgumentError; end
end
