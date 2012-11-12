module Reel
  class RackWorker
    include Celluloid

    PROTO_RACK_ENV = {
      "rack.version".freeze      => Rack::VERSION,
      "rack.errors".freeze       => STDERR,
      "rack.multithread".freeze  => true,
      "rack.multiprocess".freeze => false,
      "rack.run_once".freeze     => false,
      "rack.url_scheme".freeze   => "http",
      "SCRIPT_NAME".freeze       => ENV['SCRIPT_NAME'] || "",
      "SERVER_PROTOCOL".freeze   => "HTTP/1.1",
      "SERVER_SOFTWARE".freeze   => "Reel/#{Reel::VERSION}",
      "GATEWAY_INTERFACE".freeze => "CGI/1.1"
    }.freeze

    def initialize(handler)
      @handler, @app = handler, handler.rack_app
    end

    def handle(connection)
      while request = connection.request
        begin
          env = rack_env(request, connection)
          status, headers, body_parts = @handler.rack_app.call(env)

          body = if body_parts.respond_to?(:to_path)
            File.new(body_parts.to_path)
          else
            body_text = ""
            body_parts.each { |part| body_text += part }
            body_text
          end

          connection.respond Response.new(status, headers, body)
        ensure
          body.close if body.respond_to?(:close)
          body_parts.close if body_parts.respond_to?(:close)
        end
      end
    end

    def rack_env(request, connection)
      env = PROTO_RACK_ENV.dup

      env["SERVER_NAME"] = @handler[:host]
      env["SERVER_PORT"] = @handler[:port].to_s

      env["REMOTE_ADDR"] = connection.remote_ip
      env["REMOTE_HOST"] = connection.remote_host

      env["PATH_INFO"]   = request.path
      env["REQUEST_METHOD"] = request.method.to_s.upcase

      body = request.body || ""

      rack_input = StringIO.new(body)
      rack_input.set_encoding(Encoding::BINARY) if rack_input.respond_to?(:set_encoding)

      env["rack.input"]  = rack_input
      env["rack.logger"] = @app if Rack::CommonLogger === @app

      env["REQUEST_PATH"]      = request.path
      env["ORIGINAL_FULLPATH"] = request.path

      query_string = request.query_string || ""
      query_string += "##{request.fragment}" if request.fragment

      env["QUERY_STRING"] = query_string

      request.headers.each{|key, val|
        next if /^content-type$/i =~ key
        next if /^content-length$/i =~ key
        name = "HTTP_" + key
        name.gsub!(/-/o, "_")
        name.upcase!
        env[name] = val
      }

      host = env['HTTP_HOST'] || env["SERVER_NAME"]

      env["REQUEST_URI"] = "#{env['rack.url_scheme']}://#{host}#{request.path}"

      env
    end
  end
end
