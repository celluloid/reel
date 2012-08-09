require 'websocket_parser'

module Reel
  class WebSocket
    attr_reader :url, :headers

    def initialize(socket, url, headers)
      @socket, @url, @headers = socket, url, headers

      handshake = ::WebSocket::ClientHandshake.new(:get, url, headers)

      if handshake.valid?
        response = handshake.accept_response
        response.render(socket)
      else
        Logger.warn("Error during handshake: #{handshake.errors.first}")
        close
        return
      end

      @parser = ::WebSocket::Parser.new

      @parser.on_message do |msg|
        puts "Received message: '#{msg}'"
      end

      @parser.on_error do |ex|
        close
        raise ex
      end

      @parser.on_close do |status, reason|
        # According to the spec the server must respond with another
        # close message before closing the connection
        socket << ::WebSocket::Message.close.to_data
        close
      end

      @parser.on_ping do
        socket << ::WebSocket::Message.pong.to_data
      end
    end

    def [](header)
      @headers[header]
    end

    def read
      @parser << @socket.readpartial(Connection::BUFFER_SIZE)
    end

    def write(msg)
      @socket << ::WebSocket::Message.new(msg).to_data
      msg
    end
    alias_method :<<, :write

    def closed?
      @socket.closed?
    end

    def close
      @socket.close
    end
  end
end
