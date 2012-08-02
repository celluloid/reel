require 'spec_helper'

describe Reel::Websocket do
  it "parses incoming websockets requests" do
    with_socket_pair do |client, connection|
      client << LibWebSocket::OpeningHandshake::Client.new(:url => 'ws://www.example.com')
      request = connection.read_request

      request.url.should     eq "/"
      request.version.should eq "1.1"

      request['Host'].should eq "www.example.com"
      request['Connection'].should eq "Upgrade"
      request['Upgrade'].should eq "WebSocket"
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
