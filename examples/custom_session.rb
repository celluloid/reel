#!/usr/bin/env ruby
# Run with: bundle exec ruby examples/custom_session.rb

require 'rubygems'
require 'bundler/setup'
require 'reel'

require 'reel/session'

puts "*** Starting server on http://127.0.0.1:4567"

# All Session config parameter are optional (default parameter value will be used)
session_config1= {:session_length=>86400,:session_name=>'basic',:secret_key=>'secret'} # session_length = 24hr
Reel::Server::HTTP.new('127.0.0.1', 4567, {:session=>session_config1}) do |connection|
  connection.each_request do |request|
    # Session value can access using request.session
    if request.session[:hi]
      puts ":hi found in session: '#{request.session[:hi]}'"
    else
      request.session[:hi] = 'hello'
    end
    request.respond :ok, "hello, world!\n"
  end

end

puts "*** Starting server on http://127.0.0.1:4568"

# All Session config parameter are optional (default parameter value will be used)
session_config2 = {:session_length=>300,:session_name=>'basic',:secret_key=>'secret'} # session_length = 5min
Reel::Server::HTTP.new('127.0.0.1', 4568, {:session=>session_config2}) do |connection|
  connection.each_request do |request|
    # Session value can access using request.session
    if request.session[:bye]
      puts ":bye found in session: '#{request.session[:bye]}'"
    else
      request.session[:bye] = 'bye'
    end
    request.respond :ok, "later, world!\n"
  end

end

sleep
