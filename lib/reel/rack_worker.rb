module Reel
  class RackWorker
    include Celluloid
    include Celluloid::Logger

    INITIAL_BODY = ''

    # Freeze some HTTP header names & values
    CONTENT_TYPE_ORIG   = 'Content-Type'.freeze
    CONTENT_LENGTH_ORIG = 'Content-Length'.freeze
    CONTENT_TYPE        = 'CONTENT_TYPE'.freeze
    CONTENT_LENGTH      = 'CONTENT_LENGTH'.freeze

    SERVER_SOFTWARE     = 'SERVER_SOFTWARE'.freeze
    SERVER_NAME         = 'SERVER_NAME'.freeze
    SERVER_PORT         = 'SERVER_PORT'.freeze
    SERVER_PROTOCOL     = 'SERVER_PROTOCOL'.freeze
    GATEWAY_INTERFACE   = "GATEWAY_INTERFACE".freeze
    LOCALHOST           = 'localhost'.freeze
    HTTP_VERSION        = 'HTTP_VERSION'.freeze
    CGI_1_1             = 'CGI/1.1'.freeze
    REMOTE_ADDR         = 'REMOTE_ADDR'.freeze
    CONNECTION          = 'HTTP_CONNECTION'.freeze
    SCRIPT_NAME         = 'SCRIPT_NAME'.freeze
    PATH_INFO           = 'PATH_INFO'.freeze
    REQUEST_METHOD      = 'REQUEST_METHOD'.freeze
    QUERY_STRING        = 'QUERY_STRING'.freeze
    HTTP_1_0            = 'HTTP/1.0'.freeze
    HTTP_1_1            = 'HTTP/1.1'.freeze
    HTTP_               = 'HTTP_'.freeze
    HOST                = 'Host'.freeze
    
    # Freeze some Rack header names
    RACK_INPUT          = 'rack.input'.freeze
    RACK_LOGGER         = 'rack.logger'.freeze
    RACK_VERSION        = 'rack.version'.freeze
    RACK_ERRORS         = 'rack.errors'.freeze
    RACK_MULTITHREAD    = 'rack.multithread'.freeze
    RACK_MULTIPROCESS   = 'rack.multiprocess'.freeze
    RACK_RUN_ONCE       = 'rack.run_once'.freeze
    RACK_URL_SCHEME     = 'rack.url_scheme'.freeze
    RACK_WEBSOCKET      = 'rack.websocket'.freeze

    PROTO_RACK_ENV = {
      RACK_VERSION      => ::Rack::VERSION,
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
      body, is_stream = response_body(body_parts)
      connection.respond (is_stream ? StreamResponse : Response).new(status, headers, body)
    ensure
      unless is_stream ||= nil
        body_parts.respond_to?(:close) && (body_parts.closed? || body_parts.close)
        body.respond_to?(:close) && (body.closed? || body.close)
      end
    end

    def handle_websocket(request, connection)
      status, *rest = @app.call(websocket_env(request))
      request.close unless status < 300
    end

    def request_env request, connection
      env = env(request)
      env[REMOTE_ADDR] = connection.remote_ip
      env
    end

    def websocket_env request
      env = env(request)
      env[REMOTE_ADDR]    = request.remote_ip
      env[RACK_WEBSOCKET] = request
      env
    end

    def response_body(body_parts)
      if body_parts.respond_to?(:to_path)
        ::File.new(body_parts.to_path)
      else
        body = ''
        body_parts.each do |c|
          return [c, true] if c.is_a?(Reel::Stream)
          body << c
        end
        body
      end
    end

    private
    def env request
      env = Hash[PROTO_RACK_ENV]

      env[RACK_INPUT] = StringIO.new(request.body || INITIAL_BODY)
      env[RACK_INPUT].set_encoding(Encoding::BINARY) if env[RACK_INPUT].respond_to?(:set_encoding)
      env[SERVER_NAME], env[SERVER_PORT] = (request[HOST]||'').split(':', 2)
      env[SERVER_PORT] ||= @handler[:port].to_s
      env[HTTP_VERSION]   = request.version || env[SERVER_PROTOCOL]
      env[REQUEST_METHOD] = request.method
      env[PATH_INFO]      = request.path
      env[QUERY_STRING]   = request.query_string || ''

      (_ = request.headers.delete CONTENT_TYPE_ORIG) && (env[CONTENT_TYPE] = _)
      (_ = request.headers.delete CONTENT_LENGTH_ORIG) && (env[CONTENT_LENGTH] = _)

      request.headers.each_pair do |key, val|
        env[HTTP_ + key.gsub('-', '_').upcase] = val
      end
      env
    end
  end
end
