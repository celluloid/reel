require 'reel'

class Server < Reel::Server
  include Celluloid::Logger

  def initialize(host = '0.0.0.0', port = (ENV['PORT'] || 5000).to_i)
    super(host, port, &method(:on_connection))
  end

  def on_connection(connection)
    connection.each_request do |request|
      if request.websocket?
        handle_websocket_request(request, connection)
      else
        handle_http_request(request, connection)
      end
    end
  end

  def handle_http_request(request, connection)
    request.respond :ok, "Hello Lame"
  end

  def handle_websocket_request(request, connection)
    debug("[handle_websocket_request] method: #{request.method}, url: #{request.url}, uri: #{request.uri}, query_string: #{request.query_string}, fragment: #{request.fragment}, headers: #{request.headers}")
    request.websocket.on :open do |event|
      debug('[ws] open')
    end
    request.websocket.on :message do |event|
      debug('[ws] message')
    end
    request.websocket.on :close do |event|
      debug('[ws] close')
    end
    request.websocket.on :error do |event|
      debug('[ws] error')
    end
    request.websocket.run
    debug("[handle_websocket_request] finished")
  end

end