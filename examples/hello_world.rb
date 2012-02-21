require 'rubygems'
require 'bundler/setup'
require 'reel'

Reel::Server.new('127.0.0.1', 1234) do |connection|
  connection.respond :ok, "hello, world!"
end

sleep