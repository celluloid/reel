#!/usr/bin/env ruby
# Run with: bundle exec examples/hello_world.rb

require 'rubygems'
require 'bundler/setup'
require 'reel'

addr, port = '127.0.0.1', 4430
options = {
  :cert => File.read(File.expand_path("../../spec/fixtures/server.crt", __FILE__)),
  :key  => File.read(File.expand_path("../../spec/fixtures/server.key", __FILE__))
}

puts "*** Starting server on #{addr}:#{port}"
Reel::Server::HTTPS.supervise(addr, port, options) do |connection|
  # For keep-alive support
  connection.each_request do |request|
    # Ordinarily we'd route the request here, e.g.
    # route request.url
    request.respond :ok, "hello, world!"
  end

  # Reel takes care of closing the connection for you
  # If you would like to hand the connection off to another thread or actor,
  # use, connection.detach and then manually call connection.close when done
end

sleep
