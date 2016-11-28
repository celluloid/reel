require 'spec_helper'
require 'reel/h2'
require 'h2'

Reel::Logger.logger.level = ::Logger::FATAL
# Reel::H2.verbose!

def with_server handler = nil, &block
  handler ||= proc do |stream|
    stream.respond :ok
    stream.connection.goaway
  end

  block ||= ->{ H2::Client.get url: url }

  begin
    server = Reel::H2::Server::HTTP.new host: addr, port: port, spy: false do |c|
      c.each_stream &handler
    end
    block[server]
  ensure
    server.terminate if server && server.alive?
  end
end
