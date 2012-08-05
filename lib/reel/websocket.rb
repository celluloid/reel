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

      @parser = LibWebSocket::Frame.new
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
  end
end
