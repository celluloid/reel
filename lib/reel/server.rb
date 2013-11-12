module Reel
  # The Reel HTTP server class
  #
  # This class is a Celluloid::IO actor which provides a bareboens HTTP server
  # For HTTPS support, use Reel::SSLServer
  class Server
    include Celluloid::IO

    # How many connections to backlog in the TCP accept queue
    DEFAULT_BACKLOG = 100

    execute_block_on_receiver :initialize
    finalizer :shutdown

    # Allow the existing `new` to be called, even though we will
    # replace it with a default version that creates HTTP servers over
    # TCP sockets.
    #
    class << self
      alias_method :_new, :new
      protected    :_new
    end

    # Create a new Reel HTTP server
    #
    # @param [String] host address to bind to
    # @param [Fixnum] port to bind to
    # @option options [Fixnum] backlog of requests to accept
    # @option options [true] spy on the request
    #
    # @return [Reel::SSLServer] Reel HTTPS server actor
    #
    # ::new was overridden for backwards compatibility. The underlying
    # #initialize method now accepts a `server` param that is
    # responsible for having established the bi-directional
    # communication channel. ::new uses the existing (sane) default of
    # setting up the TCP channel for the user.
    #
    def self.new(host, port, options = {} , &callback)
      server  = Celluloid::IO::TCPServer.new(host, port)
      backlog = options.fetch(:backlog, DEFAULT_BACKLOG)

      # prevent TCP packets from being buffered
      server.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      server.listen(backlog)

      self._new(server, options, &callback)
    end

    # Create a Reel HTTP server over a UNIX socket.
    #
    # @param [String] socket_path path to the UNIX socket
    # @option options [true] spy on the request
    #
    def self.unix(socket_path, options = {}, &callback)
      server = Celluloid::IO::UNIXServer.new(socket_path)

      self._new(server, options, &callback)
    end

    def initialize(server, options = {}, &callback)
      @spy      = STDOUT if options[:spy]
      @server   = server
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
      if @spy
        require 'reel/spy'
        socket = Reel::Spy.new(socket, @spy)
      end

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
