require 'coveralls'
Coveralls.wear!

require 'bundler/setup'
require 'reel'
require 'pry'

require 'support/example_request'

logfile = File.open(File.expand_path("../../log/test.log", __FILE__), 'a')
Celluloid.logger = Logger.new(logfile)

def fixture_dir
  Pathname.new File.expand_path("../fixtures", __FILE__)
end

def example_addr; '127.0.0.1'; end
def example_port; 1234; end
def example_path; "/example"; end
def example_url;  "http://#{example_addr}:#{example_port}#{example_path}"; end

def with_reel(handler)
  server = Reel::Server::HTTP.new(example_addr, example_port, &handler)
  yield server
ensure
  server.terminate if server && server.alive?
end

def with_socket_pair
  host = '127.0.0.1'
  port = 10101

  server = TCPServer.new(host, port)
  client = TCPSocket.new(host, port)
  peer   = server.accept

  begin
    yield client, peer
  ensure
    server.close rescue nil
    client.close rescue nil
    peer.close   rescue nil
  end
end
