module Reel
  module H2
    class Server

      # 'h2' server - for TLS 1.2 ALPN HTTP/2 connection
      #
      # @see https://tools.ietf.org/html/rfc7540#section-3.3
      #
      class HTTPS < H2::Server

        ALPN_PROTOCOL        = 'h2'
        ALPN_SELECT_CALLBACK = ->(ps){ ps.find { |p| ALPN_PROTOCOL == p }}
        ECDH_CURVES          = 'P-256'
        TMP_ECDH_CALLBACK    = ->(*_){ OpenSSL::PKey::EC.new 'prime256v1' }

        # create a new h2 server that uses SNI to determine TLS cert/key to use
        #
        # @see https://en.wikipedia.org/wiki/Server_Name_Indication
        #
        # @param [String] host the IP address for this server to listen on
        # @param [Integer] port the TCP port for this server to listen on
        # @param [Hash] sni the SNI option hash with certs/keys for domains
        # @param [Hash] options
        #
        # == SNI options with default callback
        #
        # [:sni] Hash with domain name +String+ keys and +Hash+ values:
        #     [:cert] +String+ TLS certificate
        #     [:extra_chain_cert] +String+ TLS certificate
        #     [:key] +String+ TLS key
        #
        # == SNI options with _custom_ callback
        #
        # [:sni] Hash:
        #     [:callback] +Proc+ creates +OpenSSL::SSL::SSLContext+ for each
        #                        connection
        #
        def initialize host:, port:, sni:, **options, &on_connection
          @sni          = sni
          @sni_callback = @sni[:callback] || method(:sni_callback)
          @tcpserver    = Celluloid::IO::TCPServer.new host, port
          @sslserver    = Celluloid::IO::SSLServer.new @tcpserver, create_ssl_context
          options.merge! host: host, port: port, sni: sni
          super @sslserver, options, &on_connection
        end

        # accept a socket connection, possibly attach spy, hand off to +#handle_connection+
        # asyncronously, repeat
        #
        def run
          loop do
            begin
              socket = @server.accept
            rescue OpenSSL::SSL::SSLError, Errno::ECONNRESET, Errno::EPIPE,
                   Errno::ETIMEDOUT, Errno::EHOSTUNREACH => ex
              Logger.warn "Error accepting SSLSocket: #{ex.class}: #{ex.to_s}"
              retry
            end

            socket = Reel::Spy.new(socket, @spy) if @spy
            async.handle_connection socket
          end
        end

        private

        # default SNI callback - builds SSLContext from cert/key by domain name in +@sni+
        # or returns existing one if name is not found
        #
        def sni_callback args
          socket, name = args
          if sni_opts = @sni[name] and Hash === sni_opts
            create_ssl_context **sni_opts
          else
            socket.context
          end
        end

        # builds a new SSLContext suitable for use in 'h2' connections
        #
        def create_ssl_context **opts
          ctx                  = OpenSSL::SSL::SSLContext.new
          ctx.alpn_protocols   = [ALPN_PROTOCOL]
          ctx.alpn_select_cb   = ALPN_SELECT_CALLBACK
          ctx.ca_file          = opts[:ca_file] if opts[:ca_file]
          ctx.ca_path          = opts[:ca_path] if opts[:ca_path]
          ctx.cert             = context_cert opts[:cert]
          ctx.ciphers          = opts[:ciphers] || OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers]
          ctx.extra_chain_cert = context_extra_chain_cert opts[:extra_chain_cert]
          ctx.key              = context_key opts[:key]
          ctx.options          = opts[:options] || OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options]
          ctx.servername_cb    = @sni_callback
          ctx.ssl_version      = :TLSv1_2
          context_ecdh ctx
          ctx
        end

        private

        if OpenSSL::VERSION >= '2.0'
          def context_ecdh ctx
            ctx.ecdh_curves = ECDH_CURVES
          end
        else
          def context_ecdh ctx
            ctx.tmp_ecdh_callback = TMP_ECDH_CALLBACK
          end
        end

        def context_cert cert
          case cert
          when String
            cert = File.read cert if File.exist? cert
            OpenSSL::X509::Certificate.new cert
          when OpenSSL::X509::Certificate
            cert
          end
        end

        def context_key key
          case key
          when String
            key = File.read key if File.exist? key
            OpenSSL::PKey::RSA.new key
          when OpenSSL::PKey::RSA
            key
          end
        end

        def context_extra_chain_cert chain
          case chain
          when String
            chain = File.read chain if File.exist? chain
            [OpenSSL::X509::Certificate.new(chain)]
          when OpenSSL::X509::Certificate
            [chain]
          when Array
            chain
          end
        end

      end
    end
  end
end
