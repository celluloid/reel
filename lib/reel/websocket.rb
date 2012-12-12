require 'forwardable'
require 'websocket_parser'

module Reel
  class WebSocket
    extend Forwardable
    include ConnectionMixin
    include RequestMixin

    def_delegators :@socket, :addr, :peeraddr

    def initialize(http_parser, socket)
      @http_parser, @socket = http_parser, socket

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

    [:next_message, :next_messages, :on_message, :on_error, :on_close, :on_ping, :on_pong].each do |meth|
      define_method meth do |&proc|
        @parser.send __method__, &proc
      end
    end

    def read_every n, unit = :s
      cancel_timer! # only one timer allowed per stream
      seconds = case unit.to_s
      when /\Am/
        n * 60
      when /\Ah/
        n * 3600
      else
        n
      end
      @timer = Celluloid.every(seconds) { read }
    end
    alias read_interval  read_every
    alias read_frequency read_every

    def read
      @parser.append @socket.readpartial(Connection::BUFFER_SIZE) until msg = @parser.next_message
      msg
    rescue => e
      cancel_timer!
      @on_error ? @on_error.call(e) : raise(e)
    end

    def body
      nil
    end

    def write(msg)
      @socket << ::WebSocket::Message.new(msg).to_data
      msg
    rescue => e
      cancel_timer!
      @on_error ? @on_error.call(e) : raise(e)
    end
    alias_method :<<, :write

    def closed?
      @socket.closed?
    end

    def close
      cancel_timer!
      @socket.close unless closed?
    end

    def cancel_timer!
      @timer && @timer.cancel
    end

  end
end
