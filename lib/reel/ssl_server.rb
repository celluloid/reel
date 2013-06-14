module Reel
  class SSLServer < Server
    execute_block_on_receiver :initialize

    def initialize(host, port, options = {}, &callback)
      backlog = options.fetch(:backlog, DEFAULT_BACKLOG)

      # Ideally we can encapsulate this rather than making Ruby OpenSSL a
      # mandatory part of the Reel API. It would be nice to support
      # alternatives (e.g. Puma's MiniSSL)
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.cert = OpenSSL::X509::Certificate.new options.fetch(:cert)
      ssl_context.key  = OpenSSL::PKey::RSA.new options.fetch(:key)

      # FIXME: VERY VERY VERY VERY BAD RELEASE BLOCKER BAD
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE

      @tcpserver  = Celluloid::IO::TCPServer.new(host, port)
      @server = Celluloid::IO::SSLServer.new(@tcpserver, ssl_context)
      @server.listen(backlog)
      @callback = callback

      async.run
    end
  end
end
