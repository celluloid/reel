require 'reel/session/store'
require 'reel/session/crypto'
require 'celluloid/extras/hash'
require 'time'

module Reel
  module Session

    # Basic structure to visualize working of session handlers
    # TODO

    COOKIE_KEY = 'Cookie'
    SET_COOKIE = 'Set-Cookie'
    COOKIE = '%s=%s; Expires=%s; Path=/; HttpOnly'

    # default session configuration
    DEFAULT_CONFIG = {
       secret_key: 'reel_sessions_key',
       session_length: 21600, # 6 hours
       session_name: 'reel_sessions_default'
    }

    # initialize it only on first invocation
    def self.store
      @store ||= Celluloid::Extras::Hash.new
    end

    # This module will be mixed in into Reel::Request
    module RequestMixin
      include Celluloid::Internals::Logger
      include Reel::Session::Crypto

      # changing/modifying configuration
      def configuration options={}
        options = DEFAULT_CONFIG.merge options
      end

      # initializing session
      def initialize_session
        @session = Store.new self
      end

      # to expose value hash
      attr_reader :session

      # finalizing the session
      def finalize_session
        uuid = @session.save
        set_response uuid if uuid
      end

      # calculate expiry based on session length
      def session_expiry
        (Time.now + options[:session_length]).rfc2822
      end

      # set cookie with uuid in response header
      def set_response uuid
        header = Hash[SET_COOKIE => COOKIE % [
          encrypt(options[:session_name]),encrypt(uuid),session_expiry
          ] ]

          # Merge this header hash into response and encryption TODO
      end
    end

  end
end

# Current plan is to include RequestMixin methods into Reel::Request class if Reel/Session
# is required
module Reel
  class Request
    include ::Reel::Session::RequestMixin

    alias_method :base_respond, :respond
    def respond *args
      cookie_header = finalize_session
      # TODO : merge this header properly into args
      base_respond *args
    end

    class Parser
      alias_method :base_on_headers_complete, :on_headers_complete
      def on_headers_complete headers
        base_on_headers_complete headers
        current_request.initialize_session
      end
    end
  end
end
