module Reel
  module H2
    class Stream
      class Request

        # a case-insensitive hash that also handles symbol translation i.e. s/_/-/
        #
        HEADER_HASH = Hash.new do |hash, key|
          k = key.to_s.upcase
          k.gsub! '_', '-' if Symbol === key
          _, value = hash.find {|header_key,v| header_key.upcase == k}
          hash[key] = value if value
        end

        attr_reader :body, :headers, :stream

        def initialize stream
          @stream  = stream
          @headers = HEADER_HASH.dup
          @body    = ''
        end

        # retreive the IP address of the connection
        #
        def addr
          @addr ||= @stream.connection.socket.peeraddr[3] rescue nil
        end

        # retreive the HTTP method as a lowercase +Symbol+
        #
        def method
          return @method unless @method.nil?
          @method = headers[Reel::H2::METHOD_KEY]
          @method = @method.downcase.to_sym if @method
          @method
        end

        # retreive the path from the stream request headers
        #
        def path
          @path ||= headers[Reel::H2::PATH_KEY]
        end

        # respond to this request on its stream
        #
        def respond response, body_or_headers = nil, body = nil
          @stream.respond response, body_or_headers, body
        end

      end
    end
  end
end
