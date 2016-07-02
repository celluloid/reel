require 'reel/session/store'
require 'reel/session/crypto'
require 'celluloid/extras/hash'
require 'time'

module Reel
  module Session

    COOKIE_KEY = 'Cookie'.freeze
    COOKIE = '%s=%s; Expires=%s; Path=/; HttpOnly'.freeze

    # default session configuration
    DEFAULT_CONFIG = {
       :secret_key=> 'reel_sessions_key',
       :session_length=> 21600, # 6 hours
       :session_name=> 'reel_sessions_default'
    }

    # initialize it only on first invocation
    def self.store
      @store ||= Celluloid::Extras::Hash.new
    end

    # will be storing all timers for deleting Session values
    def self.timers_hash
      @timers ||= {}
    end

    # changing/modifying configuration
    def self.configuration server, options={}
      @options ||= {}
      if @options[server]
        @options[server].merge! options if Hash === options
      else
        @options[server] = DEFAULT_CONFIG.merge options if Hash === options
      end
      @options[server]
    end

    # This module will be mixed in into Reel::Request
    module RequestMixin
      include Celluloid::Internals::Logger

      # initializing session
      def initialize_session
        @bag = Store.new self
        @session = @bag.val
      end

      # to expose value hash
      attr_reader :session

      # finalizing the session
      def finalize_session
        make_header @bag.save
      end

      def session_config options={}
        @config ||= Reel::Session.configuration(self.connection.server,options)
      end

      # calculate expiry based on session length
      def session_expiry
        # changing it to .utc, as was giving problem with Chrome when setting in local time
        # with utc,can't see parsed `Expires` in Cookie tab of firefox (problem seems to be in firefox only)
        (Time.now + session_config[:session_length]).utc.rfc2822
      end

      # make header to set cookie with uuid
      def make_header uuid=nil
        crypto = Reel::Session::Crypto
        COOKIE % [crypto.encrypt(session_config[:session_name],session_config),
                  crypto.encrypt(uuid,session_config),
                  session_expiry]
      end
    end

  end
end

# Include RequestMixin methods into Reel::Request class if Reel/Session is required
module Reel

  class Server
    alias_method :base_initialize, :initialize
    def initialize(server, options={}, &callback)
      Session.configuration self, options.delete(:session)
      base_initialize server, options, &callback
    end
  end

  class Request
    include Reel::Session::RequestMixin
    SET_COOKIE = 'Set-Cookie'.freeze

    alias_method :base_respond, :respond
    def respond(response, headers_or_body = {}, body = nil)
        cookie_val = finalize_session
        cookie_header = {SET_COOKIE=>cookie_val} if cookie_val
        if cookie_header
          if Hash === headers_or_body
            headers_or_body.merge! cookie_header
          else
            body, headers_or_body = headers_or_body, cookie_header
          end
        end
        base_respond response, headers_or_body, body
      end

    class Parser
      alias_method :base_on_headers_complete, :on_headers_complete
      def on_headers_complete headers
        req = base_on_headers_complete headers
        req.initialize_session
      end
    end
  end
end
