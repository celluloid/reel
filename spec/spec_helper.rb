require 'bundler/setup'
require 'reel'

def example_addr; '127.0.0.1'; end
def example_port; 1234; end
def example_url;  "/example"; end

def with_reel(handler)
  server = Reel::Server.new(example_addr, example_port, &handler)
  yield server
ensure
  server.terminate
end