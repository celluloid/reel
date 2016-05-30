require 'celluloid-extras'

module Reel
  module Sessions
    class Store

      def find_session request
        # extract cookies from headers
        # find value in concurrent hash Store
        # return value if key present else empty hash
        # TODO
      end

      def save
          # merge key , value
          # @outer.merge!(Hash(key,value))
          # key
      end

    end
  end
end
