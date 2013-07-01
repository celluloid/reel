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
Reel::SSLServer.supervise(addr, port, options) do |connection|
  # To use keep-alive with Reel, use a while loop that repeatedly calls
  # connection.request and consumes connection objects
  while request = connection.request
    # Ordinarily we'd route the request here, e.g.
    # route request.url
    connection.respond :ok, "hello, world!"
  end

  # Reel takes care of closing the connection
end

sleep