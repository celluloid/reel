module Reel
  # Parses incoming HTTP requests
  class Request
    class Parser
      attr_reader :headers
    
      def initialize
        @parser = Http::Parser.new(self)
        @headers = nil
        @read_body = false
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
        # FIXME: handle request bodies
      end

      def on_message_complete
        @read_body = true
      end    
    end
  end
end