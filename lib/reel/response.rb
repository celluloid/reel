module Reel
  class Response
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

      @headers = {}
      headers.each do |name, value|
        name = name.to_s
        key = name[Http::CANONICAL_HEADER]
        key ||= canonicalize_header(name)
        @headers[key] = value.to_s
      end

      case @body
      when String
        @headers['Content-Length'] ||= @body.bytesize
      when IO
        @headers['Content-Length'] ||= @body.stat.size
      when Enumerable
        @headers['Transfer-Encoding'] ||= 'chunked'
      when NilClass
      else raise ArgumentError, "can't render #{@body.class} as a response body"
      end

      # Prevent modification through the accessor
      @headers.freeze

      # FIXME: real HTTP versioning
      @version = "HTTP/1.1"
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
        # TODO: IO.copy_stream when it works cross-platform
        while data = @body.read(4096)
          socket << data
        end
      when Enumerable
        @body.each do |chunk|
          chunk_header = chunk.bytesize.to_s(16) + CRLF
          socket << chunk_header
          socket << chunk
        end

        socket << "0" << CRLF * 2
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

    # Transform to canonical HTTP header capitalization
    def canonicalize_header(header)
      header.to_s.split(/[\-_]/).map(&:capitalize).join('-')
    end
    private :canonicalize_header
  end
end
