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
      @body_remaining = nil
    end

    # Is the connection still active?
    def alive?; @keepalive; end

    def read_request
      raise StateError, "can't read header" unless @request_state == :header

      begin
        until @parser.headers
          @parser << @socket.readpartial(BUFFER_SIZE)
        end
      rescue IOError, Errno::ECONNRESET, Errno::EPIPE
        @keepalive = false
        @socket.close unless @socket.closed?
        return
      end

      @request_state = :body

      headers = {}
      @parser.headers.each do |header, value|
        headers[Http.canonicalize_header(header)] = value
      end

      if headers['Connection']
        @keepalive = false if headers['Connection'] == 'close'
      elsif @parser.http_version == "1.0"
        @keepalive = false
      end

      @body_remaining = Integer(headers['Content-Length']) if headers['Content-Length']
      @request = Request.new(@parser.http_method, @parser.url, @parser.http_version, headers, self)
    end

    def readpartial(size = BUFFER_SIZE)
      if @body_remaining and @body_remaining > 0
        chunk = @parser.chunk
        unless chunk
          @parser << @socket.readpartial(size)
          chunk = @parser.chunk
          return unless chunk
        end

        @body_remaining -= chunk.length
        @body_remaining = nil if @body_remaining < 1

        chunk
      end
    end

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
    rescue IOError, Errno::ECONNRESET, Errno::EPIPE
      # The client disconnected early
      @keepalive = false
    ensure
      if @keepalive
        reset
        @request_state = :header
      else
        @socket.close unless @socket.closed?
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
