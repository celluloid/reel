require 'celluloid/extras/hash'

module Reel
  module Session
    class Store

      def initialize store,request,config
        # encryption/decryption TODO

        @store = store
        @request = request
        @config = config

        # extracting key from cookie
        if cookie = @request.headers[COOKIE_KEY]
          cookie = cookie.first if cookie.kind_of? Array
          cookie.split(';').each do |all_cookie|
            array_val = all_cookie.split('=').map &:strip
            @key = array_val[1] if array_val[0] ==  @config[:session_name]
          end
        end
        # check if key exist in our concurrent hash
        @val = @store[@key] if @store.key? @key
        # initialize new hash if key is not present in hash,cookie etc
        @val ||= Hash.new
      end


      def generate_id
        Celluloid::Internals::UUID.generate
      end

      def save
          # merge key,value
          # @key ||= generate_id
          # @store.merge!(Hash(@key,@val))
          # @key
      end

    end
  end
end
