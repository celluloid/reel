require 'libwebsocket'

module Reel
  class WebSocket
    attr_reader :url, :headers

    def initialize(socket, url, headers, buffer = nil)
      @socket, @url, @headers = socket, url, headers

      handshake = LibWebSocket::OpeningHandshake::Server.new
      handshake.parse buffer if buffer

      until handshake.done?
        if handshake.error
          response = Response.new(400)
          response.reason = handshake.error.to_s
          response.render(@socket)

          raise HandshakeError, "error during handshake: #{handshake.error}"
        end

        handshake.parse @socket.readpartial(Connection::BUFFER_SIZE)
      end

      @socket << handshake.to_s
      @parser = LibWebSocket::Frame.new
    end

    def [](header)
      @headers[header]
    end

    def read
      @parser.append @socket.readpartial(Connection::BUFFER_SIZE) until data = @parser.next
      data
    end

    def write(data)
      @socket << LibWebSocket::Frame.new(data).to_s
      data
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
