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
      body = Reel::EventStream.new do |socket|
        Connections << socket
      end
      [200, {'Content-Type' => 'text/event-stream'}, body]
    }
  end

  map '/wall' do
    run lambda { |env|
      msg = env['PATH_INFO'].gsub(/\/+/, '').strip
      msg = Time.now if msg.empty?
      
      Connections.each do |s|
        begin
          s.data(msg)
        rescue => SocketError
          Connections.delete(s)
        end
      end
      
      [200, {'Content-Type' => 'text/html'}, ["Sent \"#{msg}\" to #{Connections.size} clients"]]
    }
  end
end.to_app

Rack::Handler::Reel.run app, Port: 9292

__END__
<!doctype html>
<html lang="en">
<body>
  <div id="content">Waiting for messages...</div>
</body>
<script type="text/javascript">
var evs = new EventSource('/subscribe');
evs.onmessage = function(e){
  document.getElementById('content').innerHTML = e.data;
}
</script>
</html>
