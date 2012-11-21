module Reel
  class RackWorker
    include Celluloid
    include Celluloid::Logger

    INITIAL_BODY      = ''

    # Freeze some HTTP header names & values
    SERVER_SOFTWARE     = 'SERVER_SOFTWARE'.freeze
    SERVER_NAME         = 'SERVER_NAME'.freeze
    SERVER_PORT         = 'SERVER_PORT'.freeze
    SERVER_PROTOCOL     = 'SERVER_PROTOCOL'.freeze
    GATEWAY_INTERFACE   = "GATEWAY_INTERFACE".freeze
    LOCALHOST           = 'localhost'.freeze
    HTTP_VERSION        = 'HTTP_VERSION'.freeze
    HTTP_1_0            = 'HTTP/1.0'.freeze
    HTTP_1_1            = 'HTTP/1.1'.freeze
    CGI_1_1             = 'CGI/1.1'.freeze
    REMOTE_ADDR         = 'REMOTE_ADDR'.freeze
    CONNECTION          = 'HTTP_CONNECTION'.freeze
    SCRIPT_NAME         = 'SCRIPT_NAME'.freeze
    PATH_INFO           = 'PATH_INFO'.freeze
    REQUEST_METHOD      = 'REQUEST_METHOD'.freeze
    QUERY_STRING        = 'QUERY_STRING'.freeze
    CONTENT_TYPE        = 'Content-Type'.freeze
    CONTENT_LENGTH      = 'Content-Length'.freeze
    HTTP_               = 'HTTP_'.freeze
    HOST                = 'Host'.freeze

    # Freeze some Rack header names
    RACK_INPUT        = 'rack.input'.freeze
    RACK_LOGGER       = 'rack.logger'.freeze
    RACK_VERSION      = 'rack.version'.freeze
    RACK_ERRORS       = 'rack.errors'.freeze
    RACK_MULTITHREAD  = 'rack.multithread'.freeze
    RACK_MULTIPROCESS = 'rack.multiprocess'.freeze
    RACK_RUN_ONCE     = 'rack.run_once'.freeze
    RACK_URL_SCHEME   = 'rack.url_scheme'.freeze
    RACK_WEBSOCKET    = 'rack.websocket'.freeze

    REQUEST_METHODS   = {
      :get     => 'GET'.freeze,
      :post    => 'POST'.freeze,
      :put     => 'PUT'.freeze,
      :head    => 'HEAD'.freeze,
      :delete  => 'DELETE'.freeze,
      :options => 'OPTIONS'.freeze,
      :patch   => 'PATCH'.freeze,
    }

    PROTO_RACK_ENV = {
      RACK_VERSION      => Rack::VERSION,
      RACK_ERRORS       => STDERR,
      RACK_MULTITHREAD  => true,
      RACK_MULTIPROCESS => false,
      RACK_RUN_ONCE     => false,
      RACK_URL_SCHEME   => "http".freeze,
      SCRIPT_NAME       => ENV[SCRIPT_NAME] || "",
      SERVER_PROTOCOL   => HTTP_1_1,
      SERVER_SOFTWARE   => "Reel/#{Reel::VERSION}".freeze,
      GATEWAY_INTERFACE => CGI_1_1
    }.freeze

    def initialize(handler)
      @handler, @app = handler, handler.rack_app
    end

    def handle(connection)
      while request = connection.request
        case request
        when Request
          handle_request(request, connection)
        when WebSocket
          handle_websocket(request, connection)
        end
      end
    end

    def handle_request(request, connection)
      status, headers, body_parts = @app.call(request_env(request, connection))
      body = response_body(body_parts)

      connection.respond Response.new(status, headers, body)
    ensure
      body.close if body.respond_to?(:close)
      body_parts.close if body_parts.respond_to?(:close)
    end

    def handle_websocket(request, connection)
      status, *rest = @app.call(websocket_env(request))
      request.socket.close unless status < 300
    end

    def request_env request, connection
      env(request).merge REMOTE_ADDR => connection.remote_ip
    end

    def websocket_env request
      env(request).merge REMOTE_ADDR => request.remote_ip, RACK_WEBSOCKET => request
    end

    def response_body(body_parts)
      if body_parts.respond_to?(:to_path)
        File.new(body_parts.to_path)
      else
        body_text = ''
        body_parts.each { |part| body_text << part }
        body_text
      end
    end

    private

    def env request
      env = Hash[PROTO_RACK_ENV]

      env[RACK_INPUT] = StringIO.new(request.body || INITIAL_BODY)
      env[RACK_INPUT].set_encoding(Encoding::BINARY) if env[RACK_INPUT].respond_to?(:set_encoding)

      env[SERVER_NAME], env[SERVER_PORT] = (request[HOST]||'').split(':', 2)
      env[SERVER_PORT] ||= @handler[:port].to_s
      env[HTTP_VERSION] = request.version || env[SERVER_PROTOCOL]

      env[REQUEST_METHOD] = REQUEST_METHODS[request.method] || 
        raise(ArgumentError, "unknown request method: %s" % request.method)

      env[PATH_INFO]    = request.path
      env[QUERY_STRING] = request.query_string || ''

      # seems headers wont be used anymore so it is safe to alter them.
      (_ = request.headers.delete CONTENT_TYPE) && (env[CONTENT_TYPE] = _)
      (_ = request.headers.delete CONTENT_LENGTH) && (env[CONTENT_LENGTH] = _)

      request.headers.each_pair do |key, val|
        env[HTTP_ + key.sub('-', '_').upcase] = val
      end

      env
    end

  end
end
