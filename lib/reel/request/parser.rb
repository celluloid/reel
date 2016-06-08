module Reel
  class Request
    class Parser
      include HTTPVersionsMixin
      attr_reader :socket, :connection

      def initialize(connection)
        @parser      = HTTP::Parser.new(self)
        @connection  = connection
        @socket      = connection.socket
        @buffer_size = connection.buffer_size
        @currently_reading = @currently_responding = nil
        @pending_reads     = []
        @pending_responses = []

        reset
      end

      def add(data)
        @parser << data
      end
      alias_method :<<, :add

      def http_method
        @parser.http_method
      end

      def http_version
        # TODO: add extra HTTP_VERSION handler when HTTP/1.2 released
        @parser.http_version[1] == 1 ? HTTP_VERSION_1_1 : HTTP_VERSION_1_0
      end

      def url
        @parser.request_url
      end

      def current_request
        until @currently_responding || @currently_reading
          readpartial
        end
        @currently_responding || @currently_reading
      end

      def readpartial(size = @buffer_size)
        bytes = @socket.readpartial(size)
        @parser << bytes
      end

      #
      # HTTP::Parser callbacks
      #
      def on_headers_complete(headers)
        info = Info.new(http_method, url, http_version, headers)
        req  = Request.new(info, connection)

        if @currently_reading
          @pending_reads << req
        else
          @currently_reading = req
        end
      end

      # Send body directly to Reel::Response to be buffered.
      def on_body(chunk)
        @currently_reading.fill_buffer(chunk)
      end

      # Mark current request as complete, set this as ready to respond.
      def on_message_complete
        @currently_reading.finish_reading! if @currently_reading.is_a?(Request)

        if @currently_responding
          @pending_responses << @currently_reading
        else
          @currently_responding = @currently_reading
        end

        @currently_reading = @pending_reads.shift
      end

      def reset
        popped = @currently_responding

        if req = @pending_responses.shift
          @currently_responding = req
        elsif @currently_responding
          @currently_responding = nil
        end

        popped
      end
    end
  end
end
