module Reel
  class Server
    include Celluloid::IO

    def initialize(server_or_config, port = 3000, &callback)
      @callback = callback

      case server_or_config
      when Configuration
        @config = config
      when String
        @config = Configuration.new(['-a', server_or_config, '-p', port.to_s])
      end

      # This is actually an evented Celluloid::IO::TCPServer
      @server = TCPServer.new(@config[:host], @config[:port])

      run!
    end

    def finalize
      @server.close
    end

    def run
      loop { handle_connection! @server.accept }
    end

    def handle_connection(socket)
      connection = Connection.new(socket)
      begin
        connection.read_request
        @callback[connection] if connection.request
      end while connection.alive?
    rescue EOFError
      # Client disconnected prematurely
      # FIXME: should probably do something here
    end
  end
end