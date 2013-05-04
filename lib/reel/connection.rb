module Reel
  # A connection to the HTTP server
  class Connection
    include HTTPVersionsMixin
    include ConnectionMixin

    class StateError < RuntimeError; end # wrong state for a given operation

    CONNECTION         = 'Connection'.freeze
    TRANSFER_ENCODING  = 'Transfer-Encoding'.freeze
    KEEP_ALIVE         = 'Keep-Alive'.freeze
    CLOSE              = 'close'.freeze
    CHUNKED            = 'chunked'.freeze

    attr_reader :socket, :parser

    attr_accessor :buffered_data

    # Attempt to read this much data
    BUFFER_SIZE = 16384

    def initialize(socket)
      @attached  = true
      @socket    = socket
      @keepalive = true
      @parser    = Request::Parser.new
      reset_request

      @response_state = :header

      # Data read from the socket and not parsed yet
      @buffered_data = ""
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
    def reset_request(state = :header)
      @request_state = state
      @header_buffer = "" # Buffer headers in case of an upgrade request
      @parser.reset
    end

    # Read a request object from the connection
    def request
      return if @request_state == :websocket
      req = Request.read(self)

      case req
      when Request
        @request_state = :body
        @keepalive = false if req[CONNECTION] == CLOSE || req.version == HTTP_VERSION_1_0
      when WebSocket
        @request_state = @response_state = :websocket
        @socket = nil
      else raise "unexpected request type: #{req.class}"
      end

      req
    rescue IOError, Errno::ECONNRESET, Errno::EPIPE
      # The client is disconnected
      @request_state = :closed
      @keepalive = false
      nil
    end

    # Read a chunk from the request
    def readpartial(size = BUFFER_SIZE)
      raise StateError, "can't read in the `#{@request_state}' state" unless @request_state == :body

      # First parse buffered data, until the parser says it's full
      unless @buffered_data.empty?
        parsed_index = 0
        begin
          @parser << @buffered_data[parsed_index]
          parsed_index += 1
        end until @parser.finished? or @buffered_data.size == parsed_index

        @buffered_data = @buffered_data[parsed_index..-1] || ""
      end

      chunk = @parser.chunk
      unless chunk || @parser.finished?
        @parser << @socket.readpartial(size)
        chunk = @parser.chunk
      end

      chunk
    end

    # read length bytes from request body
    def read(length = nil, buffer = nil)
      raise ArgumentError, "negative length #{length} given" if length && length < 0

      return '' if length == 0

      res = buffer.nil? ? '' : buffer.clear

      chunk_size = length.nil? ? BUFFER_SIZE : length
      begin
        while chunk_size > 0
          chunk = readpartial(chunk_size)
          break unless chunk
          res << chunk
          chunk_size = length - res.length unless length.nil?
        end
      rescue EOFError
      end

      return length && res.length == 0 ? nil : res
    end

    # Send a response back to the client
    # Response can be a symbol indicating the status code or a Reel::Response
    def respond(response, headers_or_body = {}, body = nil)
      raise StateError "not in header state" if @response_state != :header

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
        reset_request(:header)
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
