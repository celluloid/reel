require 'rubygems'
require 'bundler/setup'
require 'reel'

addr, port = '127.0.0.1', 1234

puts "*** Starting server on #{addr}:#{port}"
Reel::Server::HTTP.new(addr, port) do |connection|
  connection.respond :ok, "Hello World"
end

sleep
