module Reel
  class HTTPServer < Server

    execute_block_on_receiver :initialize

    # Create a new Reel HTTPS server
    #
    # @param [String] host address to bind to
    # @param [Fixnum] port to bind to
    # @option options [Fixnum] backlog of requests to accept
    #
    # @return [Reel::HTTPServer] Reel HTTP server actor
    def initialize(host, port, options={}, &callback)
      optimize_socket server = Celluloid::IO::TCPServer.new(host, port)
      options.merge!({ :host => host, :port => port })
      super(server, options, &callback)
    end

    def shutdown
      deoptimize_socket @server
      super
    end

  end
end
