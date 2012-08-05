require 'libwebsocket'

module Reel
  class WebSocket
    class HandshakeError < StandardError; end

    def initialize(socket, header = nil)
      @socket = socket

      handshake = LibWebSocket::OpeningHandshake::Server.new
      handshake.parse header if header

      handshake.parse @socket.readpartial(Connection::BUFFER_SIZE) until handshake.done?
      @socket << handshake.to_s

      raise HandshakeError, "error during handshake: #{handshake.error}" if handshake.error
    end
  end
end
