module Reel
  class Server
    include Celluloid::IO
    
    def initialize(host, port, &callback)
      # What looks at first glance to be a normal TCPServer is in fact an
      # "evented" Celluloid::IO::TCPServer
      @server = TCPServer.new(host, port)
      @callback = callback
      
      run!
    end
    
    def run
      loop { handle_connection! @server.accept }
    end
    
    def handle_connection(socket)
      connection = Connection.new(socket)
      connection.read_header
      @callback.(connection)
    rescue EOFError
      # Client disconnected prematurely      
    ensure
      socket.close
    end
  end
end