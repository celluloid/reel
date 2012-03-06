module Reel
  # A connection to the HTTP server
  class Connection
    class StateError < RuntimeError; end # wrong state for a given request
    
    attr_reader :request
    
    # Attempt to read this much data
    BUFFER_SIZE = 4096
    
    def initialize(socket)
      @socket = socket
      @keepalive = true
      reset
      
      @response_state = :header
    end
    
    # Is the connection still active?
    def alive?; @keepalive; end
    
    def read_request
      raise StateError, "can't read header" unless @request_state == :header
      
      until @parser.headers
        @parser << @socket.readpartial(BUFFER_SIZE)
      end
      @request_state = :body
      
      headers = {}
      @parser.headers.each do |header, value|
        headers[Http.canonicalize_header(header)] = value
      end
      
      if @parser.http_version == "1.0" or headers['Connection'] == 'close'
        @keepalive = false
      end
      
      @body_remaining = Integer(headers['Content-Length']) if headers['Content-Length']
      @request = Request.new(@parser.http_method, @parser.url, @parser.http_version, headers, self)
    end
    
    def readpartial(size = BUFFER_SIZE)
      if @body_remaining and @body_remaining > 0
        str = @socket.readpartial(size)
        @body_remaining -= str.length
        @body_remaining = nil if @body_remaining < 1
        str
      end
    end
    alias_method :read, :readpartial
    
    def respond(response, body = nil)
      if @keepalive
        headers = {'Connection' => 'Keep-Alive'}
      else
        headers = {'Connection' => 'close'}
      end
      
      case response
      when Symbol
        response = Response.new(response, headers, body)
      when Response
      else raise TypeError, "invalid response: #{response.inspect}"
      end
      
      response.render(@socket)
    rescue Errno::ECONNRESET, Errno::EPIPE
      # The client disconnected early
      @keepalive = false
    ensure
      if @keepalive
        reset
        @request_state = :header
      else
        @socket.close 
        @request_state = :closed
      end
    end
    
    def reset
      @request_state = :header
      @parser = Request::Parser.new
      @request = nil
    end
  end
end