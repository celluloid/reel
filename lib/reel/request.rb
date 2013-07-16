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

    # Read request data from the connection. Because we read the
    # socket in large chunks and requests may be pipelined, we buffer
    # them in the connection for further reads.
    def self.read(connection)
      parser = connection.parser
      parser.reset if parser.finished?

      if connection.buffered_data.empty?
        data = connection.socket.readpartial(Connection::BUFFER_SIZE)
        connection.buffered_data << data
      end

      parsed_index = 0
      begin
        parser << connection.buffered_data[parsed_index]
        parsed_index += 1
      end until parser.headers? or connection.buffered_data.size == parsed_index

      connection.buffered_data = connection.buffered_data[parsed_index..-1] || ""

      REQUEST_METHODS[parser.http_method] ||
        raise(ArgumentError, "Unknown Request Method: %s" % parser.http_method)

      upgrade = parser.headers[UPGRADE]
      if upgrade && upgrade.downcase == WEBSOCKET
        WebSocket.new(parser, connection.socket)
      else
        Request.new(parser, connection)
      end
    end

    def_delegators :@connection, :respond, :finish_response, :close, :read

    def initialize(http_parser, connection = nil)
      @http_parser, @connection = http_parser, connection
    end

    def body
      @body ||= begin
        raise "no connection given" unless @connection

        body = "" unless block_given?
        while (chunk = @connection.readpartial)
          if block_given?
            yield chunk
          else
            body << chunk
          end
        end
        body unless block_given?
      end
    end
  end
end
