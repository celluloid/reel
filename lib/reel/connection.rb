module Reel
  # A connection to the HTTP server
  class Connection
    attr_reader :request
    
    # Attempt to read this much data
    BUFFER_SIZE = 4096
    
    def initialize(socket)
      @socket = socket
      @parser = RequestParser.new
      @request = nil
    end
    
    def read_request
      return if @request
      
      until @parser.headers
        @parser << @socket.readpartial(BUFFER_SIZE)
      end
      
      @request = Request.new(@parser.http_method, @parser.url, @parser.http_version, @parser.headers)
    end
    
    def respond(response, body = nil)
      case response
      when Symbol
        response = Response.new(response, body)
      when Response
      else raise TypeError, "invalid response: #{response.inspect}"
      end
      
      response.render(@socket)
    rescue Errno::ECONNRESET, Errno::EPIPE
      # The client disconnected early
    ensure
      # FIXME: Keep-Alive support
      @socket.close 
    end
  end
end