module Reel
  class Response
    # Use status code tables from the Http gem
    STATUS_CODES          = Http::Response::STATUS_CODES
    SYMBOL_TO_STATUS_CODE = Http::Response::SYMBOL_TO_STATUS_CODE
    CRLF = "\r\n"
    
    attr_reader   :status # Status has a special setter to coerce symbol names
    attr_accessor :reason

    def initialize(status, body_or_headers = nil, body = nil)
      self.status = status

      if body_or_headers and not body
        @body = body_or_headers
        @headers = {}
      else
        @body = body
        @headers = body_or_headers
      end

      if @body
        @headers['Content-Length'] ||= @body.length
      end

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
      socket << @body
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
  end
end
