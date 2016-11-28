#!/usr/bin/env ruby
# frozen_string_literal: true
# Run with: bundle exec examples/h2/hello_world.rb

require 'bundler/setup'
require 'reel/h2'

addr, port = '127.0.0.1', 1234

puts "*** Starting server on http://#{addr}:#{port}"
s = Reel::H2::Server::HTTP.new host: addr, port: port, spy: true do |connection|
  connection.each_stream do |stream|
    stream.respond :ok, "hello, world!\n"
  end
end

sleep
