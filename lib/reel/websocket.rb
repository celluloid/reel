require 'forwardable'
require 'websocket/driver'

module Reel
  class WebSocket
    include Celluloid::Logger
    extend Forwardable

    def initialize(request, connection)
      @request = request
      @connection = connection
      @socket = nil
    end
    
    def_delegators :driver, :on, :text, :binary, :ping, :close

    def run
      # detach the connection and manage it ourselves
      @connection.detach

      # grab socket
      @socket = @connection.socket

      # start the driver
      driver.start

      # hook into close message from client
      driver.on(:close) { @connection.close }

      begin
        loop do
          break unless @connection.alive?
          buffer = @socket.readpartial(@connection.buffer_size)
          driver.parse(buffer)
        end
      ensure
        @connection.close
      end
    rescue EOFError
      @connection.close
    end

    def url
      @request.url
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

    def write(buffer)
      # should probably raise an error here if
      # writing to socket that has not been started up yet
      @socket.write(buffer)
    end

    def close
      @connection.close if @connection.alive? && !@connection.attached?
    end

    protected

    def driver
      @driver ||= ::WebSocket::Driver.rack(self)
    end

  end
end
