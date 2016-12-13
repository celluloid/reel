module Reel
  module H2

    # base H2 server, a direct subclass of +Reel::Server+
    #
    class Server < Reel::Server

      def initialize server, **options, &on_connection
        @on_connection = on_connection
        super server, options
      end

      # build a new connection object, run it through the given block, and
      # start reading from the socket if still attached
      #
      def handle_connection socket
        connection = H2::Connection.new socket: socket, server: self
        @on_connection[connection]
        connection.read if connection.attached?
      end

      # async stream handling
      #
      def handle_stream stream
        stream.connection.each_stream[stream]
      end

      # async goaway
      #
      def goaway connection
        sleep 0.25
        connection.parser.goaway unless connection.closed?
      end

      # 'h2c' server - for plaintext HTTP/2 connection
      #
      # NOTE: browsers don't support this and probably never will
      #
      # @see https://tools.ietf.org/html/rfc7540#section-3.4
      # @see https://hpbn.co/http2/#upgrading-to-http2
      #
      class HTTP < H2::Server

        # create a new h2c server
        #
        def initialize host:, port:, **options, &on_connection
          @tcpserver = Celluloid::IO::TCPServer.new host, port
          options.merge! host: host, port: port
          super @tcpserver, options, &on_connection
        end

      end

    end

  end
end
