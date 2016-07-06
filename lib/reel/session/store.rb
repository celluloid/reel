require 'celluloid/extras/hash'

module Reel
  module Session
    class Store

      def initialize request

        @store = Reel::Session.store
        @request = request
        @config = @request.session_config

        # extracting key from cookie
        if cookie = @request.headers[COOKIE_KEY]
          cookie.split(';').each do |all_cookie|
            array_val = all_cookie.split('=').map &:strip
            # Should we check whether array_val.length > 1 before doing this? TODO
            @key = array_val[1] if array_val[0] ==  @config[:session_name]
          end
        end
        # getting value if key exist in our concurrent hash
        @val = @store[@key]
        # initialize new hash if key is not present in hash,cookie etc
        @val ||= {}
      end

      attr_reader :val

      def generate_id
        Celluloid::Internals::UUID.generate
      end

      # timer to delete value from concurrent hash/timer hash after expiry
      def start_timer
        timer_hash = Reel::Session.timers_hash
        if timer_hash.key? @key
          timer_hash[@key].reset if timer_hash[@key] && timer_hash[@key].respond_to?(:reset)
        else
          delete_time = @request.connection.server.after(@config[:session_length]){
            @store.delete @key
            timer_hash.delete @key
          }
          timer_hash[@key] = delete_time
        end
      end


      def save
          # merge key,value
          @key ||= generate_id
          @store.merge!({@key=>@val})
          start_timer
          @key
      end

    end
  end
end
