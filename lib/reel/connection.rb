module Reel
  # A connection to the HTTP server
  class Connection
    extend Forwardable
    include HTTPVersionsMixin
    include ConnectionMixin

    class StateError < RuntimeError; end # wrong state for a given operation

    CONNECTION         = 'Connection'.freeze
    TRANSFER_ENCODING  = 'Transfer-Encoding'.freeze
    KEEP_ALIVE         = 'Keep-Alive'.freeze
    CLOSE              = 'close'.freeze
    CHUNKED            = 'chunked'.freeze

    attr_reader :socket, :parser

    # Attempt to read this much data
    BUFFER_SIZE = 16384

    def initialize(socket)
      @attached  = true
      @socket    = socket
      @keepalive = true
      @parser    = Request::Parser.new(socket, self)
      # @writer    = Response::Writer.new(socket, self)
      reset_request

      @response_state = :header
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

    # Reset the current request state
    def reset_request(state = :standard)
      @request_state = state
      @outstanding_request = nil
      @parser.reset
    end

    def readpartial(size = BUFFER_SIZE)
      raise StateError, "can't read in the '#{@request_state}' state" unless @request_state == :standard
      @parser.readpartial(size)
    end

    def outstanding_request
      @outstanding_request
    end

    # Read a request object from the connection
    def request
      return if @request_state == :websocket
      raise StateError, "current request not responded to" if outstanding_request
      req = @parser.current_request

      case req
      when Request
        @request_state = :standard
        @keepalive = false if req[CONNECTION] == CLOSE || req.version == HTTP_VERSION_1_0
        @outstanding_request = req
      when WebSocket
        @request_state = @response_state = :websocket
        @socket = SocketUpgradedError
      else raise "unexpected request type: #{req.class}"
      end

      req
    rescue IOError, Errno::ECONNRESET, Errno::EPIPE
      # The client is disconnected
      @request_state = :closed
      @keepalive = false
      nil
    end

    # Send a response back to the client
    # Response can be a symbol indicating the status code or a Reel::Response
    def respond(response, headers_or_body = {}, body = nil)
      raise StateError, "not in header state" if @response_state != :header

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
      when Symbol
        response = Response.new(response, headers, body)
      when Response
      else raise TypeError, "invalid response: #{response.inspect}"
      end

      response.render(@socket)

      # Enable streaming mode
      if response.headers[TRANSFER_ENCODING] == CHUNKED and response.body.nil?
        @response_state = :chunked_body
      end
    rescue IOError, Errno::ECONNRESET, Errno::EPIPE
      # The client disconnected early
      @keepalive = false
    ensure
      if @keepalive
        reset_request(:standard)
      else
        @socket.close unless @socket.closed?
        reset_request(:closed)
      end
    end

    # Write body chunks directly to the connection
    def write(chunk)
      raise StateError, "not in chunked body mode" unless @response_state == :chunked_body
      chunk_header = chunk.bytesize.to_s(16)
      @socket << chunk_header + Response::CRLF
      @socket << chunk + Response::CRLF
    end
    alias_method :<<, :write

    # Finish the response and reset the response state to header
    def finish_response
      raise StateError, "not in body state" if @response_state != :chunked_body
      @socket << "0#{Response::CRLF * 2}"
      @response_state = :header
    end

    # Close the connection
    def close
      @keepalive = false
      @socket.close unless @socket.closed?
    end
  end
end
