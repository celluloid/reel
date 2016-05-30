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

      # changing/modifying configuration
      def configuration options={}
        options = DEFAULT_CONFIG.merge option
      end

      # initializing session
      def initialize_session req
        @session = find_session req
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
