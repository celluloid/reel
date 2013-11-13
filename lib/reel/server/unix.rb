module Reel
  class Server
    class UNIX < Server

      # Create a new Reel HTTPS server
      #
      # @option options [String] socket path to bind to
      # @option options [Fixnum] backlog of requests to accept
      #
      # @return [Reel::Server::SSL::UNIX] Reel UNIX server actor
      def initialize(socket_path, options={}, &callback)
      	server = Celluloid::IO::Server::SSL::UNIX.new(socket_path)
      	options[:socket_path] = socket_path
        super(server, options, &callback)
      end

    end
  end
end
