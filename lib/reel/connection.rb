require 'reel/request'

module Reel
  # A connection to the HTTP server
  class Connection
    include HTTPVersionsMixin
    include ConnectionMixin

    CONNECTION         = 'Connection'.freeze
    TRANSFER_ENCODING  = 'Transfer-Encoding'.freeze
    KEEP_ALIVE         = 'Keep-Alive'.freeze
    CLOSE              = 'close'.freeze

    attr_reader   :socket, :parser, :current_request
    attr_accessor :request_state, :response_state

    # Attempt to read this much data
    BUFFER_SIZE = 16384
    attr_reader :buffer_size

    def initialize(socket, buffer_size = nil)
      @attached    = true
      @socket      = socket
      @keepalive   = true
      @buffer_size = buffer_size || BUFFER_SIZE
      @parser      = Request::Parser.new(self)
      @request_fsm = Request::StateMachine.new(@socket)

      reset_request
      @response_state = :headers
    end

    # Is the connection still active?
    def alive?; @keepalive; end

    # Is the connection still attached to a Reel::Server?
    def attached?; @attached; end

    # Detach this connection from the Reel::Server and manage it independently
    def detach
      @attached = false
      self
    end

    def readpartial(size = @buffer_size)
      unless @request_fsm.state == :headers || @request_fsm.state == :body
        raise StateError, "can't read in the '#{@request_fsm.state}' request state"
      end

      @parser.readpartial(size)
    end

    # Read a request object from the connection
    def request
      raise StateError, "already processing a request" if current_request

      req = @parser.current_request
      @request_fsm.transition :headers
      @keepalive = false if req[CONNECTION] == CLOSE || req.version == HTTP_VERSION_1_0
      @current_request = req

      req
    rescue IOError, Errno::ECONNRESET, Errno::EPIPE
      @request_fsm.transition :closed
      @keepalive = false
      nil
    end

    # Enumerate the requests from this connection, since we might receive
    # many if the client is using keep-alive
    def each_request
      while req = request
        yield req

        # Websockets upgrade the connection to the Websocket protocol
        # Once we have finished processing a Websocket, we can't handle
        # additional requests
        break if req.websocket?
      end
    end

    # Send a response back to the client
    # Response can be a symbol indicating the status code or a Reel::Response
    def respond(response, headers_or_body = {}, body = nil)
      raise StateError, "not in header state" if @response_state != :headers

      if headers_or_body.is_a? Hash
        headers = headers_or_body
      else
        headers = {}
        body = headers_or_body
      end

      if @keepalive
        headers[CONNECTION] = KEEP_ALIVE
      else
        headers[CONNECTION] = CLOSE
      end

      case response
      when Symbol, Fixnum, Integer
        response = Response.new(response, headers, body)
      when Response
      else raise TypeError, "invalid response: #{response.inspect}"
      end

      if current_request
        current_request.handle_response(response)
      else
        raise RequestError
      end

      # Enable streaming mode
      if response.chunked? and response.body.nil?
        @response_state = :chunked_body
      elsif @keepalive
        reset_request
      else
        @current_request = nil
        @parser.reset
        @request_fsm.transition :closed
      end
    rescue IOError, SystemCallError, RequestError
      # The client disconnected early, or there is no request
      @keepalive = false
      @request_fsm.transition :closed
      @parser.reset
      @current_request = nil
    end

    # Close the connection
    def close
      raise StateError, "socket has been hijacked from this connection" unless @socket

      @keepalive = false
      @socket.close unless @socket.closed?
    end

    # Hijack the socket from the connection
    def hijack_socket
      # FIXME: this doesn't do a great job of ensuring we can hijack the socket
      # in its current state. Improve the state detection.
      if @request_fsm != :ready && @response_state != :headers
        raise StateError, "connection is not in a hijackable state"
      end

      @request_fsm.transition :hijacked
      @response_state = :hijacked
      socket  = @socket
      @socket = nil
      socket
    end

    # Raw access to the underlying socket
    def socket
      raise StateError, "socket has already been hijacked" unless @socket
      @socket
    end

    # Reset the current request state
    def reset_request
      @request_fsm.transition :headers
      @current_request = nil
      @parser.reset
    end
    private :reset_request

    # Set response state for the connection.
    def response_state=(state)
      if state == :headers
        reset_request
      end
      @response_state = state
    end
  end
end
