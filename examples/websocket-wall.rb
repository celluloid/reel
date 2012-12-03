require 'rubygems'
require 'bundler/setup'
require 'reel'

Connections = []
Body = DATA.read
app = Rack::Builder.new do
  map '/' do
    run lambda { |env|
      [200, {'Content-Type' => 'text/html'}, [Body]]
    }
  end

  map '/subscribe' do
    run lambda { |env|
      if socket = env['rack.websocket']
        Connections << socket
        socket.on_error { Connections.delete socket }
      end
      [200, {'Content-Type' => 'text/event-stream'}, []]
    }
  end

  map '/wall' do
    run lambda { |env|
      msg = env['PATH_INFO'].gsub(/\/+/, '').strip
      msg = Time.now if msg.empty?
      Connections.each { |s| s << msg }
      [200, {'Content-Type' => 'text/html'}, ["Sent \"#{msg}\" to #{Connections.size} clients"]]
    }
  end
end.to_app

Rack::Handler::Reel.run app, Port: 9292

__END__
<!doctype html>
<html lang="en">
<body>
  <div id="content"></div>
</body>
<script type="text/javascript">
var ws = new WebSocket('ws://' + window.location.host + '/subscribe');
ws.onmessage = function(e) {
  document.getElementById('content').innerHTML += e.data + '<br>';
}
</script>
</html>
