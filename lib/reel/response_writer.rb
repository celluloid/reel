module Reel
  class Response
    class Writer

      CRLF = "\r\n"
      def initialize(socket, connection)
        @socket = socket
        @connection = connection
      end

      # Write body chunks directly to the connection
      def write(chunk)
        chunk_header = chunk.bytesize.to_s(16)
        @socket << chunk_header + CRLF
        @socket << chunk + CRLF
      end

      # Finish the response and reset the response state to header
      def finish_response
        @socket << "0#{CRLF * 2}"
      end

      # Takes a Reel::Response and renders it
      # back over the socket.
      def handle_response(response)
        @socket << render_header(response)
        if response.respond_to?(:render)
          response.render(@socket)
        else
          case response.body
          when String
            @socket << response.body
          when IO
            begin
              if !defined?(JRUBY_VERSION)
                IO.copy_stream(response.body, @socket)
              else
                # JRuby 1.6.7 doesn't support IO.copy_stream :(
                while data = response.body.read(4096)
                  @socket << data
                end
              end
            ensure
              response.body.close
            end
          when Enumerable
            response.body.each do |chunk|
              write(chunk)
            end

            finish_response
          end
        end
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
