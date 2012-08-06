module Reel
  class Server
    include Celluloid::IO
    
    def initialize(host, port, &callback)
      # This is actually an evented Celluloid::IO::TCPServer
      @server = TCPServer.new(host, port)
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
        @callback[connection] if connection.request
      end while connection.alive?
    rescue EOFError
      # Client disconnected prematurely
      # FIXME: should probably do something here
    end
  end
end