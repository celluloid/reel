require 'bundler/setup'
require 'reel'
require 'celluloid/autostart'

require 'reel/session'

class MyConnectionHandler
  include Celluloid

  def handle_connection(connection)
    connection.each_request { |req| handle_request(req) }
  rescue Reel::SocketError
    connection.close
  end

  def handle_request(request)
    # Session value can access using request.session
    if request.session[:user_id]
      puts "found user: #{request.session[:user_id]}"
    else
      request.session[:user_id] = "temp"
    end
    request.respond :ok,"hello world!!"
  end
end

connectionPool = MyConnectionHandler.pool

# Just adding custom session length of 10 sec
session_config = {:session_length=>10}

Reel::Server::HTTP.run('127.0.0.1', 1234, {:session=>session_config}) do |connection|
  # We're handing this connection off to another actor, so
  # we detach it first before handing it off
  connection.detach

  # Let a Connection Pool handle the connections for Roflscale Applications
  connectionPool.async.handle_connection(connection)
end
