module Reel
  # Base class for Reel servers.
  #
  # This class is a Celluloid::IO actor which provides a barebones server
  # which does not open a socket itself, it just begin handling connections
  # once initialized with a specific kind of protocol-based server.

  # For specific protocol support, use:

  # Reel::Server::HTTP
  # Reel::Server::HTTPS
  # Reel::Server::UNIX ( not on jRuby yet )

  class Server
    include Celluloid::IO
    # How many connections to backlog in the TCP accept queue
    DEFAULT_BACKLOG = 100

    execute_block_on_receiver :initialize
    finalizer :shutdown

    def initialize(server, options={}, &callback)
      @spy      = STDOUT if options[:spy]
      @options  = options
      @callback = callback
      @server   = server

      @options[:rescue] ||= []
      @options[:rescue] += [
        Errno::ECONNRESET,
        Errno::EPIPE,
        Errno::EINPROGRESS,
        Errno::ETIMEDOUT,
        Errno::EHOSTUNREACH
      ]

      @server.listen(options.fetch(:backlog, DEFAULT_BACKLOG))

      async.run
    end

    def shutdown
      @server.close if @server
    end

    def run
      loop {
        begin
          socket = @server.accept
        rescue *@options[:rescue] => ex
          Logger.warn "Error accepting socket: #{ex.class}: #{ex.to_s}"
          next
        end
        async.handle_connection socket
      }
    end

    def handle_connection(socket)
      if @spy
        require 'reel/spy'
        socket = Reel::Spy.new(socket, @spy)
      end

      begin
        connection = Connection::HTTP2.new(socket)
        connection.readpartial
      rescue HTTP2ParseError => hpe
        connection = Connection.new(socket, nil, hpe.data)

        begin
          @callback.call(connection)
        ensure
          if connection.attached?
            connection.close rescue nil
          end
        end
      end
    rescue RequestError, EOFError
      # Client disconnected prematurely
      # TODO: log this?
    end

  end

  # caused by ::HTTP2::Error::HandshakeError
  # contains the data read from socket, so the HTTP 1.x parser doesn't miss out.
  #
  class HTTP2ParseError < StandardError
    attr_reader :data
    def initialize data
      @data = data
      super()
    end
  end

end
