require 'coveralls'
Coveralls.wear!

require 'bundler/setup'
require 'reel'
require 'pry'

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
  server = Reel::Server.new(example_addr, example_port, &handler)
  yield server
ensure
  server.terminate if server && server.alive?
end

def with_socket_pair(buffer_size = nil)
  host = '127.0.0.1'
  port = 10101

  server = TCPServer.new(host, port)
  client = TCPSocket.new(host, port)
  peer   = server.accept

  begin

    connection = Reel::Connection.new(peer, buffer_size)
    yield client, connection
  ensure
    server.close rescue nil
    client.close rescue nil
    peer.close   rescue nil
  end
end

class ExampleRequest
  extend Forwardable
  def_delegators :@headers, :[], :[]=
  attr_accessor  :method, :path, :version, :body

  def initialize(method = :get, path = "/", version = "1.1", headers = {}, body = nil)
    @method = method.to_s.upcase
    @path = path
    @version = "1.1"
    @headers = {
      'Host'       => 'www.example.com',
      'Connection' => 'keep-alive',
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.78 S',
      'Accept'     => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Encoding' => 'gzip,deflate,sdch',
      'Accept-Language' => 'en-US,en;q=0.8',
      'Accept-Charset'  => 'ISO-8859-1,utf-8;q=0.7,*;q=0.3'
    }.merge(headers)

    @body = nil
  end

  def to_s
    if @body && !@headers['Content-Length']
      @headers['Content-Length'] = @body.length
    end

    "#{@method} #{@path} HTTP/#{@version}\r\n" <<
    @headers.map { |k, v| "#{k}: #{v}" }.join("\r\n") << "\r\n\r\n" <<
    (@body ? @body : '')
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

      let(:handshake) { WebSocket::ClientHandshake.new(:get, example_url, handshake_headers) }
    end
  end
end
