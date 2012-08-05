require 'http/parser'
require 'http'
require 'celluloid/io'

require 'reel/version'

require 'reel/connection'
require 'reel/logger'
require 'reel/request'
require 'reel/request_parser'
require 'reel/response'
require 'reel/server'

require 'rack'
require 'rack/handler'
require 'rack/handler/reel'
require 'reel/rack_worker'

# A Reel good HTTP server
module Reel
  # The method given was not understood
  class UnsupportedMethodError < ArgumentError; end
end
