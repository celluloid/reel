module Reel
  class Server
    include Celluloid::IO

    def initialize(server_or_config, port = 3000, &callback)
      @callback = callback

      case server_or_config
      when Configuration
        @config = server_or_config
      when String
        @config = Configuration.new(['-a', server_or_config, '-p', port.to_s])
      end

      # This is actually an evented Celluloid::IO::TCPServer
      @server = TCPServer.new(@config[:host], @config[:port])

      run!
    end

    def finalize
      @server.close
    end

    def run
      loop { handle_connection! @server.accept }
    end

    def handle_connection(socket)
      connection = Connection.new(socket)

      begin
        request = connection.read_request
        next unless request && request.body

        file_path = File.join('.', 'public', request.path)

        if @callback
          @callback[connection]
        elsif File.exists?(file_path) && !File.directory?(file_path)
          serve_file file_path, connection
        else
          Actor[:worker_pool].handle(request, connection)
        end

      end while connection.alive?

    rescue EOFError
      # Client disconnected prematurely
      # FIXME: should probably do something here
    end

    def serve_file(path, connection)
      File.open(path) do |f|
        response = Response.new(200, f)
        connection.respond response
      end
    end

    def send_response(response, connection)
      connection.respond response
    end
  end
end