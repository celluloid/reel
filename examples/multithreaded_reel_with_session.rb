#!/usr/bin/env ruby
# Run with: bundle exec ruby examples/multithreaded_reel_with_session.rb

require 'rubygems'
require 'bundler/setup'
require 'reel'

require 'reel/session'

class MyConnectionHandler
  include Celluloid

  def initialize(connection)
    @connection = connection
    async.run
  rescue Reel::SocketError
    @connection.close
  end

  def run
    @connection.each_request { |req| handle_request(req) }
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

# Just adding custom session length of 10 sec
session_config = {:session_length=>10}

puts "*** Starting server with custom session on http://127.0.0.1:3000"
Reel::Server::HTTP.new('127.0.0.1', 3000, {:session=>session_config}) do |connection|
  # We're handing this connection off to another actor, so
  # we detach it first before handing it off
  connection.detach

  MyConnectionHandler.new(connection)
end

puts "*** Starting server with default session on http://127.0.0.1:3001"
Reel::Server::HTTP.new('127.0.0.1', 3001) do |connection|
  # We're handing this connection off to another actor, so
  # we detach it first before handing it off
  connection.detach

  MyConnectionHandler.new(connection)
end

sleep
