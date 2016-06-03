require 'reel/session/store'
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

    # This module will be mixed in into Reel::Request
    module RequestMixin

      def self.included klass

        # initialize session
        klass.before do
          # check request parameter to be passed TODO
          initialize_session request
        end

        # finalize session at the end
        klass.after do
          finalize_session
        end

      end

      # initialize it only on first invocation
      def self.store
        @store ||= Celluloid::Extras::Hash.new
      end

      # changing/modifying configuration
      def configuration options={}
        options = DEFAULT_CONFIG.merge options
      end

      # initializing session
      def initialize_session req
        # bag here is for default case is our concurrent hash object
        @session = Store.new self.store,req,configuration
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
          options[:session_name],uuid,session_expiry
          ] ]

          # Merge this header hash into response and encryption TODO
      end
    end
  end
end
