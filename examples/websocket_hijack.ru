# Run this as
#   bundle exec rackup -E production -s reel examples/websocket_hijack.ru

require 'websocket/protocol'

class WS
  attr_reader :env, :url

  def initialize(env)
    @env = env

    secure = Rack::Request.new(env).ssl?
    scheme = secure ? 'wss:' : 'ws:'
    @url = scheme + '//' + env['HTTP_HOST'] + env['PATH_INFO']

    @handler = WebSocket::Protocol.server(self)
  end

  def setup
    env['rack.hijack'].call
    @io = env['rack.hijack_io']

    @handler.start

    Celluloid::Actor.current.after(1) do
      loop do
        @handler.parse(@io.readpartial(1024))
      end
    end

    @handler
  end

  def write(string)
    @io.write(string)
  end
end

class App
  def self.call(env)
    if WebSocket::Protocol.websocket?(env)
      handler = WS.new(env).setup
      handler.text "fofofo"
    end
  end
end

run App
