module Reel
  class Request
    class Parser
      include HTTPVersionsMixin
      attr_reader :headers

      def initialize
        @parser = Http::Parser.new(self)
        reset
      end

      def add(data)
        @parser << data
      end
      alias_method :<<, :add

      def headers?
        !!@headers
      end

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

      def finished?; @finished; end

      #
      # Http::Parser callbacks
      #

      def on_headers_complete(headers)
        @headers = headers
      end

      def on_body(chunk)
        if @chunk
          @chunk << chunk
        else
          @chunk = chunk
        end
      end

      def chunk
        if (chunk = @chunk)
          @chunk = nil
          chunk
        end
      end

      def on_message_complete
        @finished = true
      end

      def reset
        @finished = false
        @headers  = nil
        @chunk    = nil
      end
    end
  end
end
