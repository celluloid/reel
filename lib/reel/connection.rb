module Reel
  # A connection to the HTTP server
  class Connection
    attr_reader :request
    
    # Attempt to read this much data
    BUFFER_SIZE = 4096
    
    def initialize(socket)
      @socket = socket
      @parser = Request::Parser.new
      @request = nil
      @keepalive = true
    end
    
    def read_request
      return if @request
      
      until @parser.headers
        @parser << @socket.readpartial(BUFFER_SIZE)
      end
      
      headers = {}
      @parser.headers.each do |header, value|
        headers[Http.canonicalize_header(header)] = value
      end
      @keepalive = false if headers['Connection'] == 'close'
      @request = Request.new(@parser.http_method, @parser.url, @parser.http_version, headers)
    end
    
    def respond(response, body = nil)
      case response
      when Symbol
        response = Response.new(response, {'Connection' => 'close'}, body)
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