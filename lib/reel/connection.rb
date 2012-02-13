module Reel
  # A connection to the HTTP server
  class Connection
    def initialize(socket)
      @socket = socket
      @parser = RequestParser.new
    end
    
    def read_header
      while data = @socket.readpartial(4096)
        @parser << data
      end
    end
  end
end