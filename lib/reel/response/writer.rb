module Reel
  class Response
    class Writer
      CRLF = "\r\n"

      def initialize(socket)
        @socket = socket
      end

      # Write body chunks directly to the connection
      def write(chunk)
        chunk_header = chunk.bytesize.to_s(16)
        @socket << chunk_header + CRLF
        @socket << chunk + CRLF
      rescue IOError, SystemCallError => ex
        raise Reel::SocketError, ex.to_s
      end

      # Finish the response and reset the response state to header
      def finish_response
        @socket << "0#{CRLF * 2}"
      end

      # Render a given response object to the network socket
      def handle_response(response)
        @socket << render_header(response)
        return response.render(@socket) if response.respond_to?(:render)

        case response.body
        when String
          @socket << response.body
        when IO
          Celluloid::IO.copy_stream(response.body, @socket)
        when Enumerable
          response.body.each { |chunk| write(chunk) }
          finish_response
        when NilClass
          # Used for streaming Transfer-Encoding chunked responses
          return
        else
          raise TypeError, "don't know how to render a #{response.body.class}"
        end
        response.body.close if response.body.respond_to?(:close)
      end

      # Convert headers into a string
      def render_header(response)
        response_header = "#{response.version} #{response.status} #{response.reason}#{CRLF}"
        unless response.headers.empty?
          response_header << response.headers.map do |header, value|
            "#{header}: #{value}"
          end.join(CRLF) << CRLF
        end
        response_header << CRLF
      end
      private :render_header
    end
  end
end
