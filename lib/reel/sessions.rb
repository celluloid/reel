require 'reel/sessions/store'
require 'celluloid/extras/hash'

module Reel
  module Sessions

    # Basic structure to visualize working of session handlers
    # TODO


    # default session configuration
    DEFAULT_CONFIG = {
       secret_key: 'reel_sessions_key',
       session_length: 21600, # 6 hours
       session_name: 'reel_sessions_default'
    }

    # This module will be mixed in into Reel::Request
    module SessionsMixins

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
        options = DEFAULT_CONFIG.merge option
      end

      # initializing session
      def initialize_session req
        # bag here is for default case is our concurrent hash object
        @session = Store.new self.store,req
      end

      # to expose value hash
      attr_reader :session

      # finalizing the session
      def finalize_session
        uuid = @session.save
        set_response uuid if uuid
      end

      # set cookie with uuid in response header
      def set_response uuid
        # encrypt uuid (data) and add Set_cookie into header with proper expiration
        # TODO
      end

    end

  end
end
