require 'coveralls'
Coveralls.wear!

require 'bundler/setup'
require 'reel'
require 'pry'

def fixture_dir
  Pathname.new File.expand_path("../fixtures", __FILE__)
end

def certs_dir
  Pathname.new File.expand_path('../../tmp/certs', __FILE__)
end

require 'support/example_request'
require 'support/create_certs'

RSpec.configure(&:disable_monkey_patching!)

logfile = File.open(File.expand_path("../../log/test.log", __FILE__), 'a')
Celluloid.logger = Logger.new(logfile)

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

module WebSocketHelpers
  def self.included(spec)
    spec.instance_eval do
      let(:example_host)    { "www.example.com" }
      let(:example_path)    { "/example"}
      let(:example_url)     { "ws://#{example_host}#{example_path}" }
      let :handshake_headers do
        {
          "Host"                   => example_host,
          "Upgrade"                => "websocket",
          "Connection"             => "Upgrade",
          "Sec-WebSocket-Key"      => "dGhlIHNhbXBsZSBub25jZQ==",
          "Origin"                 => "http://example.com",
          "Sec-WebSocket-Protocol" => "chat, superchat",
          "Sec-WebSocket-Version"  => "13"
        }
      end

      let :case_handshake_headers do
        {
          "HoSt"                   => example_host,
          "UpgRAde"                => "websocket",
          "ConnECTion"             => "Upgrade",
          "Sec-WebsOCket-Key"      => "dGhlIHNhbXBsZSBub25jZQ==",
          "Origin"                 => "http://example.com",
          "Sec-WEBsOCKET-pROTOCol" => "chat, superchat",
          "Sec-WEBsOCKET-vERsion"  => "13"
        }
      end

      let(:handshake) { WebSocket::ClientHandshake.new(:get, example_url, handshake_headers) }
      let(:case_handshake) do
        WebSocket::ClientHandshake.new(:get, example_url, case_handshake_headers)
      end
    end
  end
end
