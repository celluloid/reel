module Reel
  module Sessions

    # Basic structure to visualize working of session handlers
    # TODO


    # default session configuration
    DEFAULT_CONFIG = {
      # secret_key: '',
      # session_length: 0, #TODO
      # session_name: 'reel_sessions'
      # .....
    }

    # This module will be mixed in into Reel::Request
    module SessionsMixins

      # adding/changing confiuration
      def configuration options={}
        #TODO
      end

      # initializing session
      def initialize_session req
        # Extract out key from req cookie and search for uuid in our concurrent
        # hash store if found associate value to @session
        # else
        # generate new key and associate empty hash to @session
        # TODO
      end

      # to expose value hash
      attr_reader :session

      # finalizing the session
      def finalize_session
        # save the @session into concurrent hash and return its associated uuid
        # set this uuid to response header
        # TODO
      end

      # set cookie with uuid in response header
      def set_response uuid
        # encrypt uuid (data) and add Set_cookie into header with proper expiration
        # TODO
      end

    end

  end
end
