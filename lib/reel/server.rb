module Reel
  class Server
    include Celluloid::IO

    # How many connections to backlog in the TCP accept queue
    DEFAULT_BACKLOG = 100

    # FIXME: remove respond_to? check after Celluloid 1.0
    finalizer :finalize if respond_to?(:finalizer)

    def initialize(host, port, context = nil, backlog = DEFAULT_BACKLOG, &callback)
      # This is actually an evented Celluloid::IO::SSLServer
      @server = Celluloid::IO::TCPServer.new(host, port)
      if context
        @server = Celluloid::IO::SSLServer.new(@server, context)
      end
      @server.listen(backlog)
      @callback = callback
      async.run
    end

    execute_block_on_receiver :initialize

    def finalize
      @server.close if @server
    end

    def run
      loop do
        async.handle_connection @server.accept
      rescue OpenSSL::SSL::SSLError
        # Someone connected to SSL server without SSL.
        # TODO: Log this?
      end
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
