module Reel
  class Response
    attr_reader :status
    
    def initialize(status, body = '')
      self.status = status
      @body = body
      @headers = {}
      
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
      header = "#{@version} #{@status} #{@reason}\r\n"
      header << @headers.map do |header, value|
        "#{header}: #{value}"
      end.join("\r\n")
      header << "\r\n"
    end
  end
end