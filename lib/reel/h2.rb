# frozen_string_literal: true

module Reel

  module H2

    # http/2 psuedo-headers
    #
    AUTHORITY_KEY = ':authority'
    METHOD_KEY    = ':method'
    PATH_KEY      = ':path'
    SCHEME_KEY    = ':scheme'
    STATUS_KEY    = ':status'

    # turn on extra verbose debug logging
    #
    def self.verbose!
      @verbose = true
    end

    def self.verbose?
      @verbose = false unless defined?(@verbose)
      @verbose
    end

  end
end

require 'reel'
require 'reel/h2/connection'
require 'reel/h2/server'
require 'reel/h2/stream'
require 'reel/h2/stream/request'
require 'reel/h2/stream/response'
