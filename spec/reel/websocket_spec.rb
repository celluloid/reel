require 'spec_helper'

describe Reel::WebSocket do
  let(:host) { '127.0.0.1' }
  let(:port) { 10101 }
  let(:hello) { "\x81\x85\xEF\xE1$\x92\x87\x84H\xFE\x80" }
  let(:another_message) { "\x81\x8F\xCBd\x14\xC9\xAA\n{\xBD\xA3\x01f\xE9\xA6\x01g\xBA\xAA\x03q" }
  let(:ping_frame) { "\x89\x80t\xE1\xD8\x17" }
  let(:pong_opcode) { 10 }
  let(:close_frame) { "\x88\x80\xB7\b\xEA\x14" }
  let(:queue) { Queue.new }

  let(:handshake_request) do
    txt = <<-TXT
      GET /example HTTP/1.1\r
      Host: www.example.com\r
      Upgrade: websocket\r
      Connection: Upgrade\r
      Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
      Sec-WebSocket-Protocol: chat, superchat\r
      Sec-WebSocket-Version: 13\r
      Origin: http://example.com\r\n\r
    TXT

    strip_heredoc(txt)
  end

  let(:handshake_response) do
    txt = <<-TXT
      HTTP/1.1 101 Switching Protocols\r
      Upgrade: websocket\r
      Connection: Upgrade\r
      Sec-WebSocket-Accept: HSmrc0sMlYUkAGmm5OPpG2HaGWk=\r\n\r
    TXT

    strip_heredoc(txt)
  end

  before(:each) do
    @server = Celluloid::IO::TCPServer.new(host, port)
    @client = Celluloid::IO::TCPSocket.new(host, port)
    @peer = @server.accept
    @connection = Reel::Connection.new(@peer)
  end

  after(:each) do
    @client.close
    @server.close
  end

  it 'performs the websocket handshake' do
    @client.send(handshake_request, 0)

    Thread.new { Reel::WebSocket.new(@connection.request, @connection) }
    response = @client.read

    expect(response).to eq(handshake_response)
  end

  it 'responds to pings with a pong' do
    with_websocket do
      @client.send(ping_frame, 0)

      response = @client.read
      opcode = extract_opcode(response)

      expect(opcode).to eq(pong_opcode)
    end
  end

  it 'raises an error if trying to close a connection upgraded to socket' do
    with_websocket do
      expect { @connection.close }.to raise_error(Reel::StateError)
    end
  end

  it 'reads incoming frames' do
    message_handler = ->(message, _ws) { queue << message }

    with_websocket(message: message_handler) do
      @client.send(hello, 0)
      @client.send(another_message, 0)
    end

    expect(queue.pop).to eq('hello')
    expect(queue.pop).to eq('another message')
  end

  it 'writes outgoing data to its socket' do
    test_msg = 'TEST MESSAGE'
    test_msg2 = 'message received'

    open_handler = lambda do |ws|
      ws.text(test_msg)
      queue << :opened
    end

    message_handler = ->(_msg, ws) { ws.text(test_msg2) }

    with_websocket(open: open_handler, message: message_handler) do |responses|
      if responses.size > 1
        encoded_message = responses[1]
      else
        queue.pop
        encoded_message = @client.read
      end

      message1 = decode_message(encoded_message)
      @client.send(hello, 0)
      encoded_message2 = @client.read
      message2 = decode_message(encoded_message2)

      expect(message1).to eq(test_msg)
      expect(message2).to eq(test_msg2)
    end
  end

  it 'closes the socket when it receives a close frame' do
    close_handler = ->(_ws) { queue << :closed }

    with_websocket(close: close_handler) do
      expect(@peer).not_to be_closed

      @client.send(close_frame, 0)
      queue.pop

      expect(@peer).to be_closed
    end
  end

  it 'raises a RequestError when connection used after it was upgraded' do
    @client.send(handshake_request, 0)

    request = @connection.request

    Thread.new do
      Reel::WebSocket.new(request, @connection) do |ws|
        ws.on :open do
          queue << :opened
        end
      end
    end

    queue.pop
    expect { @connection.remote_host }.to raise_error(Reel::StateError)
  end

  def strip_heredoc(str)
    indent = str.scan(/^[ \t]*(?=\S)/).min.size || 0
    str.gsub(/^[ \t]{#{indent}}/, '')
  end

  def with_websocket(handlers = {})
    @client.send(handshake_request, 0)
    request = @connection.request

    message_handler = handlers[:message]
    open_handler = handlers[:open]
    close_handler = handlers[:close]

    Thread.new do
      Reel::WebSocket.new(request, @connection) do |ws|
        ws.on :message do |event|
          message_handler.call(event.data, ws) if message_handler
        end

        ws.on :open do
          open_handler.call(ws) if open_handler
        end

        ws.on :close do
          close_handler.call(ws) if close_handler
        end
      end
    end

    responses = @client.read.split("\r\n\r\n")

    yield(responses)
  end

  def extract_opcode(message)
    opcode_translation = 0b00001111
    bytes = message.bytes
    bytes[0] & opcode_translation
  end

  def decode_message(encoded_message)
    encoded_bytes = encoded_message.bytes
    mask = encoded_bytes[2..5]
    masked_message_bytes = encoded_bytes[6..-1]
    unmasked_bytes = WebSocket::Mask.mask(masked_message_bytes, mask)
    WebSocket::Driver.encode(unmasked_bytes)
  end
end
