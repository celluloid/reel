require 'forwardable'

module Reel
  class Request
    extend Forwardable
    include RequestMixin

    UPGRADE   = 'Upgrade'.freeze
    WEBSOCKET = 'websocket'.freeze

    # Array#include? seems slow compared to Hash lookup
    request_methods = Http::METHODS.map { |m| m.to_s.upcase }
    REQUEST_METHODS = Hash[request_methods.zip(request_methods)].freeze

    def self.build(request_info, connection)
      REQUEST_METHODS[request_info.http_method] ||
        raise(ArgumentError, "Unknown Request Method: %s" % request_info.http_method)

      upgrade = request_info.headers[UPGRADE]
      if upgrade && upgrade.downcase == WEBSOCKET
        WebSocket.new(request_info, connection.socket)
      else
        Request.new(request_info, connection)
      end
    end

    def_delegators :@connection, :<<, :write, :respond, :finish_response

    def initialize(request_info, connection = nil)
      @request_info = request_info
      @connection = connection
      @finished_read = false
    end

    # Returns true if request fully finished reading
    def finished_reading?;  @finished_read;  end

    def finish_reading
      @finished_read = true
    end

    def add_body(chunk)
      if @on_body
        @on_body.call(chunk)
      else
        @body ||= ""
        @body << chunk
      end
    end

    def body
      raise "no connection given" unless @connection

      if block_given?
        @on_body = Proc.new(&block)
        yield @body if @body
        until finished_reading?
          @connection.readpartial
          yield chunk
        end
      else
        until finished_reading?
          @connection.readpartial
        end
        @body
      end
    end

    # Reads a certain amount of bytes, checking current body buffer
    # then asking the connection to read until the remainder of bytes
    # is available.
    def read_from_body(length = nil)
      if length.nil?
        slice = body
        @body = nil
      else
        unless finished_reading? || @body.length >= length
          @connection.readpartial(length - @body.length)
        end
        @body ||= ''
        slice = @body[0..length]

        # Reset buffer to not include bytes already read
        @body = @body[length..-1]
      end
      slice || ''
    end

    def read(length = nil, buffer = nil)
      raise ArgumentError, "negative length #{length} given" if length && length < 0

      return '' if length == 0
      res = buffer.nil? ? '' : buffer.clear
      chunk = read_from_body(length)
      res << chunk
      return length && res.length == 0 ? nil : res
    end
  end
end
