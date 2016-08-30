#!/usr/bin/env ruby
# Run with: bundle exec examples/hello_world_multipart.rb

require 'rubygems'
require 'bundler/setup'
require 'reel'
require 'reel/request/multipart'

addr, port = '127.0.0.1', 1234

puts "*** Starting server on http://#{addr}:#{port}"
Reel::Server::HTTP.run(addr, port) do |connection|
  connection.each_request do |request|
    if request.multipart?
      request.multipart.each do |key,val|
        puts File.read(val[:data])
      end
      request.respond :ok, "Hello world!! Got multipart post!!"
    else
      request.respond 400, "Expecting Multipart Request!!"
    end

  end

end
