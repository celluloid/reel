require 'celluloid/extras/hash'
require 'reel/session/crypto'

module Reel
  module Session
    class Store
      include Crypto
      include Celluloid

      def initialize request

        @store = Reel::Session.store
        @request = request
        @config = @request.session_config

        # extracting key from cookie
        if cookie = @request.headers[COOKIE_KEY]
          cookie.split(';').each do |all_cookie|
            array_val = all_cookie.split('=').map &:strip
            # Should we check whether array_val.length > 1 before doing this? TODO
            @key = decrypt(array_val[1]) if decrypt(array_val[0]) ==  @config[:session_name]
          end
        end
        # check if key exist in our concurrent hash
        @val = @store[@key] if @store.key? @key
        # initialize new hash if key is not present in hash,cookie etc
        @val ||= Hash.new
      end

      attr_reader :val

      def generate_id
        Celluloid::Internals::UUID.generate
      end

      # timer to delete value from concurrent hash/timer hash after expiry
      def start_timer
        return unless @key
        timer_hash = Reel::Session.timers_hash
        if timer_hash.key? @key
          timer_hash[@key].reset
        else
          delete_time = @request.connection.server.after(@config[:session_length]){
            @store.delete @key
            timer_hash.delete @key
          }
          timer_hash[@key] = delete_time
        end
      end


      def save
        return if @val.empty?
          # merge key,value
          @key ||= generate_id
          @store.merge!({@key=>@val})
          start_timer
          @key
      end

    end
  end
end
