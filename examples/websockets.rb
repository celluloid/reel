# FIXME: not quite complete yet, but it should give you an idea

require 'rubygems'
require 'bundler/setup'
require 'reel'

class TimeServer
  include Celluloid
  include Celluloid::Notifications

  def initialize
    run!
  end

  def run
    now = Time.now.to_f
    sleep now.ceil - now + 0.001

    every(1) { publish 'time_change', Time.now }
  end
end

class TimeClient
  include Celluloid
  include Celluloid::Notifications

  def initialize(websocket)
    @socket = websocket
    subscribe('time_change', :notify_time_change)
  end

  def notify_time_change(topic, new_time)
    @socket << new_time.inspect
  end
end

class WebServer < Reel::Server
  include Celluloid::Logger

  def initialize(host = "127.0.0.1", port = 1234)
    info "Time server example starting on #{host}:#{port}"
    super(host, port, &method(:on_connection))
  end

  def on_connection(connection)
    while request = connection.request
      case request
      when Reel::Request
        route_request connection, request
      when Reel::WebSocket
        TimeClient.new(request)
      end
    end
  end

  def route_request(connection, request)
    if request.url == "/"
      return render_index(connection)
    end

    info "404 Not Found: #{request.path}"
    connection.respond :not_found, "Not found"
  end

  def render_index(connection)
    info "200 OK: /"
    connection.respond :ok, <<-HTML
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>Reel WebSockets time server example</title>
        <style>
          body {
            font-family: "HelveticaNeue-Light", "Helvetica Neue Light", "Helvetica Neue", Helvetica, Arial, "Lucida Grande", sans-serif;
            font-weight: 300;
            text-align: center;
          }

          #content {
            width: 800px;
            margin: 0 auto;
            background: #EEEEEE;
            padding: 1em;
          }
        </style>
      </head>
      <script>
        var SocketKlass = "MozWebSocket" in window ? MozWebSocket : WebSocket;
        var ws = new SocketKlass('ws://' + window.location.host + '/timeinfo');
        ws.onmessage = function(msg){
          document.getElementById('current-time').innerHTML = msg.data;
        }
      </script>
      <body>
        <div id="content">
          <h1>Time Server Example</h1>
          <div>The time is now: <span id="current-time">...</span></div>
        </div>
      </body>
      </html>
    HTML
  end
end

TimeServer.supervise_as :time_server
WebServer.supervise_as :reel

sleep
