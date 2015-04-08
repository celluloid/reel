require 'forwardable'
require 'websocket/driver'

module Reel
  class WebSocket
    extend Forwardable
    include ConnectionMixin
    include RequestMixin

    attr_reader :socket
    def_delegators :@socket, :addr, :peeraddr

    def initialize(info, connection)
      driver_env = DriverEnvironment.new(info, connection.socket)

      @socket = connection.hijack_socket
      @request_info = info

      @driver = ::WebSocket::Driver.rack(driver_env)
      @driver.on(:close) do
        @socket.close
      end

      @message_stream = MessageStream.new(@socket, @driver)
      @driver.start
    rescue EOFError
      close
    end

    def on_message(&block)
      @driver.on :message do |message|
        block.(message.data)
      end
    end

    [:error, :close, :ping, :pong].each do |meth|
      define_method "on_#{meth}" do |&proc|
        @driver.send(:on, meth, &proc)
      end
    end

    def read_every(n, unit = :s)
      cancel_timer! # only one timer allowed per stream
      seconds = case unit.to_s
      when /\Am/
        n * 60
      when /\Ah/
        n * 3600
      else
        n
      end
      @timer = Celluloid.every(seconds) { read }
    end
    alias read_interval  read_every
    alias read_frequency read_every

    def read
      @message_stream.read
    end

    def closed?
      @socket.closed?
    end

    def write(msg)
      if msg.is_a? String
        @driver.text(msg)
      elsif msg.is_a? Array
        @driver.binary(msg)
      else
        raise "Can only send byte array or string over driver."
      end
    rescue IOError, Errno::ECONNRESET, Errno::EPIPE
      cancel_timer!
      raise SocketError, "error writing to socket"
    rescue
      cancel_timer!
      raise
    end
    alias_method :<<, :write

    def close
      @driver.close
      @socket.close
    end

    def cancel_timer!
      @timer && @timer.cancel
    end

    private

    class DriverEnvironment
      extend Forwardable

      attr_reader :env, :url, :socket

      def_delegators :socket, :write

      RACK_HEADERS = {
        'Sec-WebSocket-Key'        => 'HTTP_SEC_WEBSOCKET_KEY',
        'Sec-WebSocket-Extensions' => 'HTTP_SEC_WEBSOCKET_EXTENSIONS',
        'Sec-WebSocket-Protocol'   => 'HTTP_SEC_WEBSOCKET_PROTOCOL',
        'Sec-WebSocket-Version'    => 'HTTP_SEC_WEBSOCKET_VERSION'
      }

      def initialize(info, socket)
        @env, @url = {}, info.url
        RACK_HEADERS.each {|k,v| @env[v] = info.headers[k]}
        @socket = socket
      end
    end

    class MessageStream
      def initialize(socket, driver)
        @socket = socket
        @driver = driver
        @message_buffer = []

        @driver.on :message do |message|
          @message_buffer.push(message.data)
        end
      end

      def read
        while @message_buffer.empty?
          buffer = @socket.readpartial(Connection::BUFFER_SIZE)
          @driver.parse(buffer)
        end
        @message_buffer.shift
      end
    end
  end
end
