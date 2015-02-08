require 'forwardable'
require 'websocket/driver'
require 'rack'

module Reel
  class WebSocket
    include Celluloid::Logger
    include ConnectionMixin
    include RequestMixin

    attr_accessor :socket
    
    def initialize(info, connection)
      driver_env = DriverEnvironment.new(info, connection.socket)      
      
      @socket = connection.hijack_socket
      @request_info = info

      @driver = ::WebSocket::Driver.rack(driver_env)
      @driver.on(:close) do |code, reason|
        info "#{code} WebSocket closed, reason: #{reason}"
        @socket.close
      end

      @message_stream = MessageStream.new(@socket, @driver)
      @driver.start
    rescue EOFError
      close
    end

    [:message, :error, :close, :ping, :pong].each do |meth|
      define_method "on_#{meth}" do |&proc|
        @driver.send :on, meth, &proc
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

    private

    class DriverEnvironment
      extend Forwardable

      attr_reader :env, :url, :socket

      def_delegators :socket, :write

      def initialize(info, socket)
        @url = info.url

        env_hash = Hash[info.headers.map { |key, value| ['HTTP_' + key.upcase.gsub('-','_'),value ] }]
        
        env_hash.merge!({
          :method       => info.method,
          :input        => info.body.to_s,
          'REMOTE_ADDR' => info.remote_addr
        })

        @env = ::Rack::MockRequest.env_for(@url, env_hash)

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
