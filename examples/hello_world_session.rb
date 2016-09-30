#!/usr/bin/env ruby
# Run with: bundle exec examples/hello_world_session.rb

require 'rubygems'
require 'bundler/setup'
require 'reel'

require 'reel/session'

addr, port = '127.0.0.1', 1234

puts "*** Starting server with default session config on http://#{addr}:#{port}"
Reel::Server::HTTP.run(addr, port) do |connection|
  # For keep-alive support
  connection.each_request do |request|
    # Ordinarily we'd route the request here, e.g.
    # route request.url
    # Session value can access using request.session
    if request.session[:user_id]
      puts "found user: #{request.session[:user_id]}"
    else
      request.session[:user_id] = "temp"
    end
    # Updated Session value will be stored in store at response
    request.respond :ok, "hello, world!"
  end

  # Reel takes care of closing the connection for you
  # If you would like to hand the connection off to another thread or actor,
  # use, connection.detach and then manually call connection.close when done
end
