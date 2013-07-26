require 'forwardable'

module Reel
  class Request
    extend Forwardable
    include RequestMixin

    def self.build(request_info, connection)
      request_info.method ||
        raise(ArgumentError, "Unknown Request Method: %s" % request_info.http_method)

      if request_info.websocket_request?
        WebSocket.new(request_info, connection.socket)
      else
        Request.new(request_info, connection)
      end
    end

    def_delegators :@connection, :<<, :write, :respond, :finish_response

    # request_info is a RequestInfo object including the headers and
    # the url, method and http version.
    #
    # Access it through the RequestMixin methods.
    def initialize(request_info, connection = nil)
      @request_info = request_info
      @connection = connection
      @finished_read = false
    end

    # Returns true if request fully finished reading
    def finished_reading?;  @finished_read;  end

    # When HTTP Parser marks the message parsing as complete, this will be set.
    def finish_reading!
      @finished_read = true
    end

    # Buffer body sent from connection, or send it directly to
    # the @on_body callback if set (calling #body with a block)
    def add_body(chunk)
      if @on_body
        @on_body.call(chunk)
      else
        @body ||= ""
        @body << chunk
      end
    end

    # Returns the body, if a block is given, the body is streamed
    # to the block as the chunks become available, until the body
    # has been read.
    #
    # If no block is given, the entire body will be read from the
    # connection into the body buffer and then returned.
    def body
      raise "no connection given" unless @connection

      if block_given?
        # Callback from the http_parser will be calling add_body directly
        @on_body = Proc.new

        # clear out body buffered so far
        yield read_from_body(nil) if @body

        until finished_reading?
          @connection.readpartial
        end
        @on_body = nil
      else
        until finished_reading?
          @connection.readpartial
        end
        @body
      end
    end

    # Read a number of bytes, looping until they are available or until
    # read_from_body returns nil, indicating there are no more bytes to read
    #
    # Note that bytes read from the body buffer will be cleared as they are
    # read.
    def read(length = nil, buffer = nil)
      raise ArgumentError, "negative length #{length} given" if length && length < 0

      return '' if length == 0
      res = buffer.nil? ? '' : buffer.clear

      chunk_size = length.nil? ? @connection.buffer_size : length
      begin
        while chunk_size > 0
          chunk = read_from_body(chunk_size)
          break unless chunk
          res << chunk
          chunk_size = length - res.length unless length.nil?
        end
      rescue EOFError
      end
      return length && res.length == 0 ? nil : res
    end

    # @private
    # Reads a number of bytes from the byte buffer, asking
    # the connection to add to the buffer if there are not enough
    # bytes available.
    #
    # Body buffer is cleared as bytes are read from it.
    def read_from_body(length = nil)
      if length.nil?
        slice = @body
        @body = nil
      else
        @body ||= ''
        unless finished_reading? || @body.length >= length
          @connection.readpartial(length - @body.length)
        end
        slice = @body.slice!(0, length)
      end
      slice && slice.length == 0 ? nil : slice
    end
    private :read_from_body

  end
end
