module Reel
  class Request
    class Parser
      include HTTPVersionsMixin
      BUFFER_SIZE = 16384

      attr_reader :socket, :connection

      def initialize(sock, conn)
        @parser = Http::Parser.new(self)
        @socket = sock
        @connection = conn
        @current = nil
        @incoming = []
        @pending = []

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
        until @current
          readpartial
        end
        @current
      end

      def readpartial(size = BUFFER_SIZE)
        bytes = @socket.readpartial(size)
        @parser << bytes
        bytes
      end

      #
      # Http::Parser callbacks
      #
      def on_headers_complete(headers)
        @incoming << Request.build(headers, self, connection)
      end

      def on_body(chunk)
        @incoming.first.add_body(chunk)
      end

      def on_message_complete
        req = @incoming.shift
        req.finish_reading if req.is_a?(Request)
        if @current.nil?
          @current = req
        else
          @pending << req
        end
      end

      def reset
        popped = @current
        if req = @pending.shift
          @current = req
        elsif @current
          @current = nil
        end
        popped
      end
    end
  end
end
