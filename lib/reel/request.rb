require 'forwardable'

require 'reel/request/body'
require 'reel/request/info'
require 'reel/request/parser'
require 'reel/request/state_machine'

require 'reel/response/writer'

module Reel
  class Request
    extend Forwardable
    include RequestMixin

    def_delegators :@connection, :remote_addr, :respond
    def_delegator  :@response_writer, :handle_response
    attr_reader :body

    # request_info is a RequestInfo object including the headers and
    # the url, method and http version.
    #
    # Access it through the RequestMixin methods.
    def initialize(request_info, connection = nil)
      @request_info    = request_info
      @connection      = connection
      @finished        = false
      @buffer          = ""
      @finished_read   = false
      @websocket       = nil
      @body            = Request::Body.new(self)
      @response_writer = Response::Writer.new(connection.socket)
    end

    # Returns true if request fully finished reading
    def finished_reading?; @finished_read; end

    # When HTTP Parser marks the message parsing as complete, this will be set.
    def finish_reading!
      raise StateError, "already finished" if @finished_read
      @finished_read = true
    end

    # Fill the request buffer with data as it becomes available
    def fill_buffer(chunk)
      @buffer << chunk
    end

    # Read a number of bytes, looping until they are available or until
    # readpartial returns nil, indicating there are no more bytes to read
    def read(length = nil, buffer = nil)
      raise ArgumentError, "negative length #{length} given" if length && length < 0

      return '' if length == 0
      res = buffer.nil? ? '' : buffer.clear

      chunk_size = length.nil? ? @connection.buffer_size : length
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

    # Read a string up to the given number of bytes, blocking until some
    # data is available but returning immediately if some data is available
    def readpartial(length = nil)
      if length.nil? && @buffer.length > 0
        slice = @buffer
        @buffer = ""
      else
        unless finished_reading? || (length && length <= @buffer.length)
          @connection.readpartial(length ? length - @buffer.length : @connection.buffer_size)
        end

        if length
          slice = @buffer.slice!(0, length)
        else
          slice = @buffer
          @buffer = ""
        end
      end

      slice && slice.length == 0 ? nil : slice
    end

    # Write body chunks directly to the connection
    def write(chunk)
      unless @connection.response_state == :chunked_body
        raise StateError, "not in chunked body mode"
      end

      @response_writer.write(chunk)
    end
    alias_method :<<, :write

    # Finish the response and reset the response state to header
    def finish_response
      raise StateError, "not in body state" if @connection.response_state != :chunked_body
      @response_writer.finish_response
      @connection.response_state = :headers
    end

    # Can the current request be upgraded to a WebSocket?
    def websocket?; @request_info.websocket_request?; end

    # Return a Reel::WebSocket for this request, hijacking the socket from
    # the underlying connection
    def websocket
      @websocket ||= begin
        raise StateError, "can't upgrade this request to a websocket" unless websocket?  
        WebSocket.new(self, @connection)
      end
    end

    # Friendlier inspect
    def inspect
      "#<#{self.class} #{method} #{url} HTTP/#{version} @headers=#{headers.inspect}>"
    end
  end
end
