require 'spec_helper'

describe Reel::WebSocket do
  let(:example_message) { "Hello, World!" }
  let(:another_message) { "What's going on?" }

  it "performs websocket handshakes" do
    with_socket_pair do |client, connection|
      handshake = LibWebSocket::OpeningHandshake::Client.new(:url => 'ws://www.example.com')

      client << handshake.to_s
      websocket = connection.read_request
      websocket.should be_a Reel::WebSocket

      handshake.parse client.readpartial(4096) until handshake.done?
      handshake.error.should be_nil
    end
  end

  it "reads frames" do
    with_websocket_pair do |client, websocket|
      client << LibWebSocket::Frame.new(example_message).to_s
      client << LibWebSocket::Frame.new(another_message).to_s

      websocket.read.should == example_message
      websocket.read.should == another_message
    end
  end

  it "writes frames" do
    with_websocket_pair do |client, websocket|
      websocket.write example_message
      websocket << another_message

      frame_parser = LibWebSocket::Frame.new

      frame_parser.append client.readpartial(4096) until first_message = frame_parser.next
      first_message.should == example_message

      frame_parser.append client.readpartial(4096) until next_message = frame_parser.next
      next_message.should == another_message
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

  def with_websocket_pair
    with_socket_pair do |client, connection|
      handshake = LibWebSocket::OpeningHandshake::Client.new(:url => 'ws://www.example.com')
      client << handshake.to_s
      websocket = connection.read_request
      websocket.should be_a Reel::WebSocket

      handshake.parse client.readpartial(4096) until handshake.done?
      handshake.error.should be_nil

      yield client, websocket
    end
  end
end
