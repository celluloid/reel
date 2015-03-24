require 'bundler/setup'
require 'reel'

class MyConnectionHandler
  include Celluloid

  def handle_connection(connection)
    connection.each_request { |req| handle_request(req) }
  rescue Reel::SocketError
    connection.close
  end

  def handle_request(request)
    request.respond :ok, ''
  end
end

connectionPool = MyConnectionHandler.pool

Reel::Server::HTTP.run('127.0.0.1', 3000) do |connection|
  # We're handing this connection off to another actor, so
  # we detach it first before handing it off
  connection.detach

  # Let a Connection Pool handle the connections for Roflscale Applications
  connectionPool.async.handle_connection(connection)
end
