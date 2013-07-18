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

    def self.build(headers, parser, connection)
      REQUEST_METHODS[parser.http_method] ||
        raise(ArgumentError, "Unknown Request Method: %s" % parser.http_method)

      upgrade = headers[UPGRADE]
      if upgrade && upgrade.downcase == WEBSOCKET
        WebSocket.new(headers, parser, connection.socket)
      else
        Request.new(headers, parser, connection)
      end
    end

    def_delegators :@connection, :respond, :finish_response, :close

    def initialize(headers, http_parser, connection = nil)
      @headers = headers
      @http_parser, @connection = http_parser, connection
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
      raise "no http_parser given" unless @http_parser

      if block_given?
        @on_body = Proc.new(&block)
        yield @body if @body
        until finished_reading?
          @http_parser.readpartial
          yield chunk
        end
      else
        until finished_reading?
          @http_parser.readpartial
        end
        @body
      end
    end

    def read_from_body(length = nil)
      if length.nil?
        slice = body
        @body = nil
      else
        unless finished_reading? || @body.length >= length
          @http_parser.readpartial(length - @body.length)
        end
        @body ||= ''
        slice = @body[0..length]
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
