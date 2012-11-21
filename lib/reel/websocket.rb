require 'websocket_parser'

module Reel
  class WebSocket
    include RemoteConnection
    include URIParts

    attr_reader :url, :headers, :method, :version

    def initialize(socket, method, url, headers)
      @socket, @method, @url, @headers = socket, method, url, headers

      handshake = ::WebSocket::ClientHandshake.new(:get, url, headers)

      if handshake.valid?
        response = handshake.accept_response
        response.render(socket)
      else
        error = handshake.errors.first

        response = Response.new(400)
        response.reason = handshake.errors.first
        response.render(@socket)

        raise HandshakeError, "error during handshake: #{error}"
      end

      @parser = ::WebSocket::Parser.new

      @parser.on_close do |status, reason|
        # According to the spec the server must respond with another
        # close message before closing the connection
        @socket << ::WebSocket::Message.close.to_data
        close
      end

      @parser.on_ping do
        @socket << ::WebSocket::Message.pong.to_data
      end
    end

    def [](header)
      @headers[header]
    end

    def read
      @parser.append @socket.readpartial(Connection::BUFFER_SIZE) until msg = @parser.next_message
      msg
    end

    def body
      nil
    end

    def write(msg)
      @socket << ::WebSocket::Message.new(msg).to_data
      msg
    rescue Errno::EPIPE
      raise SocketError, "error writing to socket"
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
