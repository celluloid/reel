require 'forwardable'
require 'websocket/driver'

module Reel
  class WebSocket
    extend Forwardable
    include ConnectionMixin
    include RequestMixin

    attr_reader :socket
    def_delegators :@socket, :addr, :peeraddr
    def_delegators :@driver, :ping

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

      attr_reader :env, :socket

      def_delegator :@info, :url
      def_delegator :@socket, :write

      RACK_HEADERS = {
        'HTTP_ORIGIN'                   => 'Origin',
        'HTTP_SEC_WEBSOCKET_KEY'        => 'Sec-WebSocket-Key',
        'HTTP_SEC_WEBSOCKET_KEY1'       => 'Sec-WebSocket-Key1',
        'HTTP_SEC_WEBSOCKET_KEY2'       => 'Sec-WebSocket-Key2',
        'HTTP_SEC_WEBSOCKET_EXTENSIONS' => 'Sec-WebSocket-Extensions',
        'HTTP_SEC_WEBSOCKET_PROTOCOL'   => 'Sec-WebSocket-Protocol',
        'HTTP_SEC_WEBSOCKET_VERSION'    => 'Sec-WebSocket-Version'
      }.freeze

      def initialize(info, socket)
        @info, @socket = info, socket
        @env = Hash.new {|h,k| @info.headers[RACK_HEADERS[k]]}
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
