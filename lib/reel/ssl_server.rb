module Reel
  class SSLServer < Server
    execute_block_on_receiver :initialize

    # Create a new Reel HTTPS server
    #
    # @param [String] host address to bind to
    # @param [Fixnum] port to bind to
    # @option options [Fixnum] backlog of requests to accept
    #
    # @return [Reel::SSLServer] Reel HTTPS server actor
    def initialize(host, port, options = {}, &callback)
      backlog = options.fetch(:backlog, DEFAULT_BACKLOG)
      @spy    = STDOUT if options[:spy]

      # Ideally we can encapsulate this rather than making Ruby OpenSSL a
      # mandatory part of the Reel API. It would be nice to support
      # alternatives (e.g. Puma's MiniSSL)
      ssl_context         = OpenSSL::SSL::SSLContext.new
      ssl_context.cert    = OpenSSL::X509::Certificate.new options.fetch(:cert)
      ssl_context.key     = OpenSSL::PKey::RSA.new options.fetch(:key)

      ssl_context.ca_file = options[:ca_file]
      ssl_context.ca_path = options[:ca_path]

      # if verify_mode isn't explicitly set, verify peers if we've
      # been provided CA information that would enable us to do so
      ssl_context.verify_mode = case
        when options.include?(:verify_mode) then options[:verify_mode]
        when options.include?(:ca_file)     then OpenSSL::SSL::VERIFY_PEER
        when options.include?(:ca_path)     then OpenSSL::SSL::VERIFY_PEER
        else                                     OpenSSL::SSL::VERIFY_NONE
      end

      @tcpserver  = Celluloid::IO::TCPServer.new(host, port)
      @server     = Celluloid::IO::SSLServer.new(@tcpserver, ssl_context)

      @server.listen(backlog)
      @callback = callback

      async.run
    end

    def run
      loop do
        begin
          socket = @server.accept
        rescue OpenSSL::SSL::SSLError => ex
          Logger.warn "Error accepting SSLSocket: #{ex.class}: #{ex.to_s}"
          retry
        end

        async.handle_connection socket
      end
    end
  end
end
