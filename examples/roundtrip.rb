require 'rubygems'
require 'bundler/setup'
require 'reel'
require 'celluloid/autostart'


class RoundtripServer 
  include Celluloid
  include Celluloid::Notifications

  def initialize
    async.run
  end

  def run
    now = Time.now.to_f
    sleep now.ceil - now + 0.001
    every(1) do 
      publish 'read_message'
      end
  end
end

class Writer
  include Celluloid
  include Celluloid::Notifications
  include Celluloid::Logger

  def initialize(websocket)
    info "Writing to socket"
    @socket = websocket
    subscribe('write_message', :new_message)
  end

  def new_message(topic, new_time)
    @socket << new_time.inspect
  rescue Reel::SocketError
    info "WS client disconnected"
    terminate
  end

end

class Reader
  include Celluloid
  include Celluloid::Notifications
  include Celluloid::Logger

  def initialize(websocket)
    info "Reading socket"
    @socket = websocket
    subscribe('read_message', :new_message)
  end

   def new_message(topic)
    msg = @socket.read
    publish 'write_message', msg 
  rescue Reel::SocketError, EOFError
    info "WS client disconnected"
    terminate
  end
end

class WebServer < Reel::Server::HTTP
  include Celluloid::Logger

  def initialize(host = "0.0.0.0", port = 9000)
    info "Roundtrip example starting on #{host}:#{port}"
    super(host, port, &method(:on_connection))
  end

  def on_connection(connection)
    while request = connection.request
      if request.websocket?
        info "Received a WebSocket connection"

        # We're going to hand off this connection to another actor (Writer/Reader)
        # However, initially Reel::Connections are "attached" to the
        # Reel::Server::HTTP actor, meaning that the server manages the connection
        # lifecycle (e.g. error handling) for us.
        #
        # If we want to hand this connection off to another actor, we first
        # need to detach it from the Reel::Server (in this case, Reel::Server::HTTP)
        connection.detach

        route_websocket request.websocket
        return
      else
        route_request connection, request
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

  def route_websocket(socket)
    if socket.url == "/ws"
      Writer.new(socket)
      Reader.new(socket)
    else
      info "Received invalid WebSocket request for: #{socket.url}"
      socket.close
    end
  end

  def render_index(connection)
    info "200 OK: /"
    connection.respond :ok, <<-HTML
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>Reel WebSockets roundtrip example</title>
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
      <body>
        <div id="content">
          <h1>Roundtrip communication with websockets</h1>
          <div>
           <input id="text_input" type="text" name="q" value="" autocomplete="off"/>
           Latest message is: <span id="current-time">...</span></div>
        </div>
      </body>
      <script>
        var SocketKlass = "MozWebSocket" in window ? MozWebSocket : WebSocket;
        var ws = new SocketKlass('ws://' + window.location.host + '/ws');
        ws.onmessage = function(msg){
          document.getElementById('current-time').innerHTML = msg.data;
        };
        var input = document.getElementById("text_input");
        input.focus();     
        input.onkeydown = function(evt) {       
          var evt = evt || window.event;
          if (evt.keyCode === 13) {
            ws.send(input.value);console.log(input.value); 
            input.value = "";  
          }
        };
      </script>
      </html>
    HTML
  end
end

RoundtripServer.supervise_as :roundtrip_server
WebServer.supervise_as :reel

sleep
