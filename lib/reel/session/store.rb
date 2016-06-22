require 'celluloid/extras/hash'
require 'reel/session/crypto'

module Reel
  module Session
    class Store
      include Crypto

      def initialize request

        @store = Reel::Session.store
        @request = request
        @config = request.configuration

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

      def save
        return if @val.empty?
          # merge key,value
          @key ||= generate_id
          @store.merge!({@key=>@val})
          Reel::Session.start_timer @key,@config[:session_length]
          @key
      end

    end
  end
end
