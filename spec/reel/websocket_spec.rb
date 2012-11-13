require 'spec_helper'

describe Reel::WebSocket do
  include WebSocketHelpers

  let(:example_message) { "Hello, World!" }
  let(:another_message) { "What's going on?" }

  it "performs websocket handshakes" do
    with_socket_pair do |client, connection|
      client << handshake.to_data

      websocket = connection.request
      websocket.should be_a Reel::WebSocket

      handshake.errors.should be_empty
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
      client << WebSocket::Message.new(example_message).to_data
      client << WebSocket::Message.new(another_message).to_data

      websocket.read.should == example_message
      websocket.read.should == another_message
    end
  end

  it "writes messages" do
    with_websocket_pair do |client, websocket|
      websocket.write example_message
      websocket.write another_message

      parser = WebSocket::Parser.new

      parser.append client.readpartial(4096) until first_message = parser.next_message
      first_message.should == example_message

      parser.append client.readpartial(4096) until next_message = parser.next_message
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
      client << handshake.to_data
      websocket = connection.request
      websocket.should be_a Reel::WebSocket

      # Discard handshake
      client.readpartial(4096)

      yield client, websocket
    end
  end
end
