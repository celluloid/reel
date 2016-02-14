require 'http/2'

module Reel
  class Connection

    # HTTP/2 connection handler
    #
    class HTTP2
      include Celluloid::Logger

      BUFFER_SIZE = 16384

      attr_reader :buffer_size, :parser, :socket

      class << self

        # accessor for event generic http/2 callbacks
        #
        # @return [Hash] eventname => handler proc
        #
        def on event = nil, &block
          @on ||= {}
          return @on if event.nil?
          raise ArgumentError unless block_given?
          @on[event] = block
          @on
        end

      end

      # fire up a new connection on the socket
      #
      def initialize socket
        @socket = socket
        @parser = ::HTTP2::Server.new

        @parser.on :frame do |bytes|
          @socket.write bytes
        end

        @parser.on :stream do |stream|

          req, buffer = {}, ''
          stream.on(:headers) {|h| req = Hash[*h.flatten]}
          stream.on(:data)    {|d| buffer << d}

          stream.on(:half_close) do
            HTTP2.on[:stream][{ headers: req, body: buffer, stream: stream }]
          end

        end

      end

      # shovel data from the socket into the parser.
      #
      def readpartial
        while !@socket.closed? && !@socket.eof?
          begin
            data = @socket.readpartial(@buffer_size)
            @parser << data
          rescue ::HTTP2::Error::HandshakeError => he
            raise HTTP2ParseError.new data
          rescue => e
            error "Exception: #{e}, #{e.message} - closing socket."
            @socket.close
          end
        end
      end

    end
  end

end
