module Reel
  class Server
    include Celluloid::IO

    # How many connections to backlog in the TCP accept queue
    DEFAULT_BACKLOG = 100

    execute_block_on_receiver :initialize
    finalizer :shutdown

    def initialize(host, port, backlog = DEFAULT_BACKLOG, &callback)
      # This is actually an evented Celluloid::IO::TCPServer
      @server = TCPServer.new(host, port)
      @server.listen(backlog)
      @callback = callback
      async.run
    end

    def shutdown
      @server.close if @server
    end

    def run
      loop { async.handle_connection @server.accept }
    end

    def handle_connection(socket)
      connection = Connection.new(socket)

      begin
        @callback.call(connection)
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
