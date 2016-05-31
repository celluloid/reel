require 'celluloid/extras/hash'

module Reel
  module Sessions
    class Store

      def initialize store,request
        # extract cookies from headers
        # find value in concurrent hash Store
        # return value if key present else empty hash
        # TODO

        @store = store

      end

      def save
          # merge key,value
          # @store.merge!(Hash(key,value))
          # key
      end

    end
  end
end
