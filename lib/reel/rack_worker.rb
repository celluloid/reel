module Reel
  class RackWorker
    include Celluloid

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
    REMOTE_HOST         = 'REMOTE_HOST'.freeze
    CONNECTION          = 'HTTP_CONNECTION'.freeze
    SCRIPT_NAME         = 'SCRIPT_NAME'.freeze
    PATH_INFO           = 'PATH_INFO'.freeze
    REQUEST_METHOD      = 'REQUEST_METHOD'.freeze
    REQUEST_PATH        = 'REQUEST_PATH'.freeze
    ORIGINAL_FULLPATH   = 'ORIGINAL_FULLPATH'.freeze
    QUERY_STRING        = 'QUERY_STRING'.freeze
    REQUEST_URI         = 'REQUEST_URI'.freeze
    CONTENT_TYPE_RGXP   = /^content-type$/i.freeze
    CONTENT_LENGTH_RGXP = /^content-length$/i.freeze
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
    ASYNC_CALLBACK    = 'async.callback'.freeze
    ASYNC_CLOSE       = 'async.close'.freeze
    ASYNC_CONNECTION  = 'async.connection'.freeze

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
        begin
          env = rack_env(request, connection)
          status, headers, body_parts = @app.call(env)
          body = response_body(body_parts)

          connection.respond Response.new(status, headers, body)
        ensure
          body.close if body.respond_to?(:close)
          body_parts.close if body_parts.respond_to?(:close)
        end
      end
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

    def rack_env(request, connection)
      env = PROTO_RACK_ENV.dup

      env[SERVER_NAME] = request[HOST].to_s.split(':').first || @handler[:Host]
      env[SERVER_PORT] = @handler[:port].to_s

      case request
      when WebSocket
        env[REMOTE_ADDR] = request.remote_ip
        env[REMOTE_HOST] = request.remote_host
        env[ASYNC_CONNECTION] = request
      when Request
        env[REMOTE_ADDR] = connection.remote_ip
        env[REMOTE_HOST] = connection.remote_host
      end

      env[REMOTE_ADDR] = connection.remote_ip
      env[REMOTE_HOST] = connection.remote_host

      env[PATH_INFO]   = request.path
      env[REQUEST_METHOD] = request.method.to_s.upcase

      env[RACK_INPUT] = StringIO.new(request.body || INITIAL_BODY)
      env[RACK_INPUT].set_encoding(Encoding::BINARY) if env[RACK_INPUT].respond_to?(:set_encoding)

      env[RACK_LOGGER] = @app if Rack::CommonLogger === @app

      env[REQUEST_PATH] = request.path
      env[ORIGINAL_FULLPATH] = request.path
      env[REQUEST_URI] = request.path

      query_string = request.query_string || ''
      query_string << "##{request.fragment}" if request.fragment

      env[HTTP_VERSION] ||= env[SERVER_PROTOCOL]
      env[QUERY_STRING] = query_string

      request.headers.each do |key, val|
        next if CONTENT_TYPE_RGXP =~ key
        next if CONTENT_LENGTH_RGXP =~ key
        name = HTTP_ + key
        name.gsub!(/-/o, '_')
        name.upcase!
        env[name] = val
      end

      env
    end
  end
end
