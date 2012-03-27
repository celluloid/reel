module Reel
  # Parses incoming HTTP requests
  class Request
    class Parser
      attr_reader :headers

      def initialize
        @parser = Http::Parser.new(self)
        @headers = nil
        @finished = false
        @chunk = nil
      end

      def add(data)
        @parser << data
      end
      alias_method :<<, :add

      def headers?
        !!@headers
      end

      def http_method
        @parser.http_method.downcase.to_sym
      end

      def http_version
        @parser.http_version.join(".")
      end

      def url
        @parser.request_url
      end

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
    end
  end
end
