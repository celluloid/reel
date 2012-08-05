require 'spec_helper'

describe Reel::WebSocket do
  it "parses incoming websockets requests" do
    with_socket_pair do |client, connection|
      handshake = LibWebSocket::OpeningHandshake::Client.new(:url => 'ws://www.example.com')

      client << handshake.to_s
      websocket = connection.read_request
      websocket.should be_a Reel::WebSocket

      handshake.parse client.readpartial(4096) until handshake.done?
      handshake.error.should be_nil
    end
  end

  def with_socket_pair
    host = '127.0.0.1'
    port = 10103

    server = TCPServer.new(host, port)
    client = TCPSocket.new(host, port)
    peer   = server.accept

    begin
      yield client, Reel::Connection.new(peer)
    ensure
      server.close rescue nil
      client.close rescue nil
      peer.close   rescue nil
    end
  end
end
