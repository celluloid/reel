module Reel
  class Response

    CONTENT_LENGTH     = 'Content-Length'.freeze
    TRANSFER_ENCODING  = 'Transfer-Encoding'.freeze
    CHUNKED            = 'chunked'.freeze

    # Use status code tables from the Http gem
    STATUS_CODES          = Http::Response::STATUS_CODES
    SYMBOL_TO_STATUS_CODE = Http::Response::SYMBOL_TO_STATUS_CODE
    CRLF = "\r\n"

    attr_reader   :status # Status has a special setter to coerce symbol names
    attr_accessor :reason # Reason can be set explicitly if desired
    attr_reader   :headers, :body

    def initialize(status, body_or_headers = nil, body = nil)
      self.status = status

      if body_or_headers.is_a?(Hash)
        headers = body_or_headers
        @body = body
      else
        headers = {}
        @body = body_or_headers
      end

      case @body
      when String
        headers[CONTENT_LENGTH] ||= @body.bytesize
      when IO
        headers[CONTENT_LENGTH] ||= @body.stat.size
      when Enumerable
        headers[TRANSFER_ENCODING] ||= CHUNKED
      when NilClass
      else raise TypeError, "can't render #{@body.class} as a response body"
      end

      @headers = canonicalize_headers(headers)
      @version = http_version
    end

    # Set the status
    def status=(status, reason=nil)
      case status
      when Integer
        @status = status
        @reason ||= STATUS_CODES[status]
      when Symbol
        if code = SYMBOL_TO_STATUS_CODE[status]
          self.status = code
        else
          raise ArgumentError, "unrecognized status symbol: #{status}"
        end
      else
        raise TypeError, "invalid status type: #{status.inspect}"
      end
    end

    # Write the response out to the wire
    def render(socket)
      socket << render_header

      case @body
      when String
        socket << @body
      when IO
        begin
          if !defined?(JRUBY_VERSION)
            IO.copy_stream(@body, socket)
          else
            # JRuby 1.6.7 doesn't support IO.copy_stream :(
            while data = @body.read(4096)
              socket << data
            end
          end
        ensure
          @body.close
        end
      when Enumerable
        @body.each do |chunk|
          chunk_header = chunk.bytesize.to_s(16)
          socket << chunk_header + CRLF
          socket << chunk + CRLF
        end

        socket << "0#{CRLF * 2}"
      end
    end

    # Convert headers into a string
    # FIXME: this should probably be factored elsewhere, SRP and all
    def render_header
      response_header = "#{@version} #{@status} #{@reason}#{CRLF}"

      unless @headers.empty?
        response_header << @headers.map do |header, value|
          "#{header}: #{value}"
        end.join(CRLF) << CRLF
      end

      response_header << CRLF
    end
    private :render_header

    def canonicalize_headers headers
      headers.inject({}) do |headers, (header, value)|
        headers.merge Http.canonicalize_header(header) => value.to_s
      end.freeze
    end
    private :canonicalize_headers

    def http_version
      # FIXME: real HTTP versioning
      "HTTP/1.1".freeze
    end
    private :http_version

  end
end
