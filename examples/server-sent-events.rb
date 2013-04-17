require 'rubygems'
require 'bundler/setup'
require 'reel'
require 'reel/app'

class ServerSideEvents
  include Reel::App

  def initialize(host, port)
    super
    @connections = []
    @body = DATA.read
  end

  get '/' do
    [200, {'Content-Type' => 'text/html'}, @body]
  end

  get '/subscribe' do
    Celluloid.logger.info "subscribing a client"
    body = Reel::EventStream.new do |socket|
      @connections << socket
    end
    Celluloid.logger.info "subscribing a client"
    [200, {'Content-Type' => 'text/event-stream'}, body]
  end

  get '/wall' do
    msg = "" # env['PATH_INFO'].gsub(/\/+/, '').strip
    msg = Time.now.to_s if msg.empty?

    Celluloid.logger.info "sending a message to clients: #{msg.inspect}"
    @connections.each do |s|
      begin
        s.data(msg)
      rescue SocketError
        @connections.delete(s)
      end
    end

    [200, {'Content-Type' => 'text/html'}, "Sent \"#{msg}\" to #{@connections.size} clients"]
  end
end

ServerSideEvents.new("0.0.0.0", 9292)
sleep

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
