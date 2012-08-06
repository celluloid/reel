require 'spec_helper'

describe Reel::WebSocket do
  let(:example_host)    { "www.example.com" }
  let(:example_path)    { "/example"}
  let(:example_url)     { "ws://#{example_host}#{example_path}" }
  let(:example_message) { "Hello, World!" }
  let(:another_message) { "What's going on?" }

  it "performs websocket handshakes" do
    with_socket_pair do |client, connection|
      handshake = LibWebSocket::OpeningHandshake::Client.new(:url => example_url)

      client << handshake.to_s
      websocket = connection.request
      websocket.should be_a Reel::WebSocket

      handshake.parse client.readpartial(4096) until handshake.done?
      handshake.error.should be_nil
    end
  end

  it "knows its URL" do
    with_websocket_pair do |_, websocket|
      websocket.url.should == example_path
    end
  end

  it "knows its headers" do
    with_websocket_pair do |_, websocket|
      websocket['Host'].should == example_host
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

  it "closes" do
    with_websocket_pair do |_, websocket|
      websocket.should_not be_closed
      websocket.close
      websocket.should be_closed
    end
  end

  def with_websocket_pair
    with_socket_pair do |client, connection|
      handshake = LibWebSocket::OpeningHandshake::Client.new(:url => example_url)
      client << handshake.to_s
      websocket = connection.request
      websocket.should be_a Reel::WebSocket

      handshake.parse client.readpartial(4096) until handshake.done?
      handshake.error.should be_nil

      yield client, websocket
    end
  end
end
