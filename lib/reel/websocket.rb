require 'forwardable'
require 'websocket/driver'

module Reel
  class WebSocket
    include Celluloid::Logger
    extend Forwardable

    def_delegators :request, :url
    def_delegators :socket, :write

    def initialize(request, connection)
      @request = request
      @connection = connection
      @socket = @connection.hijack_socket

      @driver = ::WebSocket::Driver.rack(self)
      @driver.on(:close) { @connection.close }

      @message_stream = MessageStream.new(@socket, @driver)

      @driver.start
    rescue EOFError
      close
    end

    def read
      @message_stream.read
    end

    def env
      @env ||= begin
        e = {
          :method       => @request.method,
          :input        => @request.body.to_s,
          'REMOTE_ADDR' => @request.remote_addr
        }.merge(Hash[@request.headers.map { |key, value| ['HTTP_' + key.upcase.gsub('-','_'),value ] }])
        ::Rack::MockRequest.env_for(url, e)
      end
    end

    def close
      @driver.close
      @connection.close if @connection.alive? && !@connection.attached?
    end

    private
    class MessageStream
      def initialize(socket, driver)
        @socket = socket
        @driver = driver
        @message_buffer = message_buffer

        @driver.on :message do |message|
          @message_buffer.push(message)
        end
      end

      def read
        @driver.parse(@socket.readpartial(Connection::BUFFER_SIZE) until @message_buffer.length > 0
        @message_buffer.shift
      end
    end
  end
end
