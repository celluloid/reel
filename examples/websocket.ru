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
  include Celluloid::Logger

  def initialize(websocket)
    info "Streaming time changes to client"
    @socket = websocket
    subscribe('time_change', :notify_time_change)
  end

  def notify_time_change(topic, new_time)
    @socket << new_time.inspect
  rescue Reel::SocketError
    info "Time client disconnected"
    terminate
  end
end

class Web
  include Celluloid::Logger

  def render_index
    info "200 OK: /"
    <<-HTML
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

run Rack::URLMap.new(
  "/" => Proc.new{ [200, {"Content-Type" => "text/html"}, [Web.new.render_index]]},
  "/timeinfo" => Proc.new{ |env|
    TimeClient.new(env["async.connection"])
  }
)
