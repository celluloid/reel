require 'forwardable'
require 'websocket/driver'
require 'rack'

module Reel
  class WebSocket
    extend Forwardable

    NO_PREFIX_HEADERS = %w(CONTENT_TYPE CONTENT_LENGTH).freeze

    attr_reader :env, :url, :socket
    def_delegators :driver, :text, :binary, :ping, :close
    def_delegators :socket, :write

    def initialize(request, connection)
      @connection = connection
      @socket = @connection.socket
      @url = request.url

      options = {
        :method       => request.method,
        :input        => request.body.to_s,
        'REMOTE_ADDR' => request.remote_addr
      }.merge(convert_headers(request.headers))

      @env = ::Rack::MockRequest.env_for(url, options)

      @connection.detach
      @connection.hijack_socket

      driver.on(:close) { close }

      yield driver if block_given?

      driver.start

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
      @driver ||= ::WebSocket::Driver.rack(self)
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
