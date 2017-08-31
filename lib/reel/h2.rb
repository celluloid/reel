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

    ALPN_OPENSSL_MIN_VERSION = 0x10002001

    class << self

      def alpn?
        !jruby? && OpenSSL::OPENSSL_VERSION_NUMBER >= ALPN_OPENSSL_MIN_VERSION && RUBY_VERSION >= '2.3'
      end

      def jruby?
        return @jruby if defined? @jruby
        @jruby = RUBY_ENGINE == 'jruby'
      end

      # turn on extra verbose debug logging
      #
      def verbose!
        @verbose = true
      end

      def verbose?
        @verbose = false unless defined?(@verbose)
        @verbose
      end

    end

  end
end

require 'reel'
require 'reel/h2/connection'
require 'reel/h2/push_promise'
require 'reel/h2/server'
require 'reel/h2/server/https'
require 'reel/h2/stream'
require 'reel/h2/stream/request'
require 'reel/h2/stream/response'
