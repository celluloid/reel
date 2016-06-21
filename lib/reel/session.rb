require 'reel/session/store'
require 'reel/session/crypto'
require 'celluloid/extras/hash'
require 'time'

module Reel
  module Session
    extend Celluloid

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

    # start Celluloid timer to delete value from concurrent hash/timer hash after expiry
    def self.start_timer uuid,time
      @timer_hash ||= {}
      return unless uuid
      if @timer_hash.key? uuid
        @timer_hash[uuid].reset
      else
        delete_time = after(time){
          store.delete uuid
          @timer_hash.delete uuid
        }
        @timer_hash[uuid] = delete_time
      end
    end

    # changing/modifying configuration
    def self.configuration options={}
      if @options
        @options.merge! options if options.is_a? Hash
      else
        @options = DEFAULT_CONFIG.merge options if options.is_a? Hash
      end
      @options
    end

    # This module will be mixed in into Reel::Request
    module RequestMixin
      include Celluloid::Internals::Logger
      include Reel::Session::Crypto

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

      # calculate expiry based on session length
      def session_expiry
        # changing it to .utc, as was giving problem with Chrome when setting in local time
        # with utc,can't see parsed `Expires` in Cookie tab of firefox (problem seems to be in firefox only)
        (Time.now + Reel::Session.configuration[:session_length]).utc.rfc2822
      end

      # make header to set cookie with uuid
      def make_header uuid=nil
        return unless uuid
        COOKIE % [encrypt(Reel::Session.configuration[:session_name]),encrypt(uuid),session_expiry]
      end
    end

  end
end

# Include RequestMixin methods into Reel::Request class if Reel/Session is required
module Reel
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
