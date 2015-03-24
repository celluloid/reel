module Reel
  class Request
    # Represents the bodies of Requests
    class Body
      include Enumerable

      def initialize(request)
        @request   = request
        @streaming = nil
        @contents  = nil
      end

      # Read exactly the given amount of data
      def read(length)
        stream!
        @request.read(length)
      end

      # Read up to length bytes, but return any data that's available
      def readpartial(length = nil)
        stream!
        @request.readpartial(length)
      end

      # Iterate over the body, allowing it to be enumerable
      def each
        while chunk = readpartial
          yield chunk
        end
      end

      def empty?
        to_str.empty?
      end

      # Eagerly consume the entire body as a string
      def to_str
        return @contents if @contents
        raise StateError, "body is being streamed" unless @streaming.nil?

        begin
          @streaming = false
          @contents = ""
          while chunk = @request.readpartial
            @contents << chunk
          end
        rescue
          @contents = nil
          raise
        end

        @contents
      end
      alias_method :to_s, :to_str

      # Easier to interpret string inspect
      def inspect
        "#<#{self.class}:#{object_id.to_s(16)} @streaming=#{!!@streaming}>"
      end

      # Assert that the body is actively being streamed
      def stream!
        raise StateError, "body has already been consumed" if @streaming == false
        @streaming = true
      end
      private :stream!
    end
  end
end
