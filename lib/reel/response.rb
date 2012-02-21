module Reel
  class Response
    attr_reader :status
    CRLF = "\r\n"
    
    def initialize(status, body_or_headers = nil, body = nil)
      self.status = status
      
      if body_or_headers and not body
        @body = body_or_headers
        @headers = {}
      else
        @body = body
        @headers = body_or_headers
      end
      
      # hax
      @version = "HTTP/1.1"
    end
    
    # Set the status
    def set_status(status, reason = nil)
      case status
      when Integer
        @status = status
        @reason = reason
      when Symbol
        # hax!
        if status == :ok
          @status = 200
          @reason = reason || "OK"
        else
          raise ArgumentError, "unrecognized status symbol :/"
        end
      else
        raise ArgumentError, "invalid status: #{status}"
      end
    end
    alias_method :status=, :set_status
    
    # Write the response out to the wire
    def render(socket)
      socket << render_header
      socket << @body
    end
    
    #######
    private
    #######
    
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
  end
end