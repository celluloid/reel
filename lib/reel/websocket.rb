require 'forwardable'
require 'websocket/driver'

module Reel
  class WebSocket
    extend Forwardable

    NO_PREFIX_HEADERS = %w(CONTENT_TYPE CONTENT_LENGTH).freeze

    attr_reader :env, :url, :socket
    def_delegators :driver, :text, :binary, :ping, :close
    def_delegators :socket, :write

    def initialize(connection)
      @connection = connection
      @socket = @connection.socket

      @connection.detach
      @connection.hijack_socket

      driver.on(:close) { close }
      driver.on(:connect) { driver.start }

      yield driver if block_given?

      start_listening
    end

    def close
      socket.close unless socket.closed?
    end

    def start_listening
      loop do
        break if socket.closed?
        buffer = socket.readpartial(@connection.buffer_size)
        driver.parse(buffer)
      end
    rescue EOFError
      close
    end

    private

    def driver
      @driver ||= ::WebSocket::Driver.server(self)
    end

    def convert_headers(headers)
      prefixed_headers = headers.map do |key, value|
        header = key.upcase.gsub('-', '_')

        if NO_PREFIX_HEADERS.member?(header)
          [header, value]
        else
          ['HTTP_' + header, value]
        end
      end

      Hash[prefixed_headers]
    end
  end
end
