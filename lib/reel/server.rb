module Reel
  class Server
    include Celluloid::IO

    def initialize(host, port, &callback)
      # This is actually an evented Celluloid::IO::TCPServer
      @server = TCPServer.new(host, port)
      @server.listen(1024)
      @callback = callback
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
        @callback[connection]
      ensure
        if connection.attached?
          connection.close rescue nil
        end
      end
    rescue RequestError, EOFError
      # Client disconnected prematurely
      # TODO: log this?
    end
  end
end
