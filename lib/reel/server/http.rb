module Reel
  class Server
    class HTTP < Server

      # Create a new Reel HTTP server
      #
      # @param [String] host address to bind to
      # @param [Fixnum] port to bind to
      # @option options [Fixnum] backlog of requests to accept
      #
      # @return [Reel::Server::HTTP] Reel HTTP server actor
      def initialize(host, port, options={}, &callback)
        server = Celluloid::IO::TCPServer.new(host, port)
        options.merge!(host: host, port: port)
        super(server, options, &callback)
      end

    end
  end
end
