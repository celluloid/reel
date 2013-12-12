#!/usr/bin/env ruby
# Run with: bundle exec examples/hello_world.rb

require 'rubygems'
require 'bundler/setup'
require 'reel'

addr, port = '127.0.0.1', 1234

puts "*** Starting server on http://#{addr}:#{port}"
Reel::Server::HTTP.run(addr, port, spy: true) do |connection|
  # For keep-alive support
  connection.each_request do |request|
    # Ordinarily we'd route the request here, e.g.
    # route request.url
    request.respond :ok, "hello, world!\n"
  end

  # Reel takes care of closing the connection for you
  # If you would like to hand the connection off to another thread or actor,
  # use, connection.detach and then manually call connection.close when done
end
