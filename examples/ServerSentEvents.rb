#!/usr/bin/env ruby
# Run with: bundle exec examples/sse.rb
# Test with: curl -vNH 'Accept: text/event-stream' -H 'Last-Event-ID: 1' -H 'Cache-Control: no-cache' http://localhost:63334

require 'bundler/setup'
require 'celluloid/autostart'
require 'time'
require 'reel'

class TimePusher
  include Celluloid
  include Celluloid::Notifications

  def initialize
    async.ring
  end

  def ring
    every(2) do
      publish(:time, Time.now.httpdate)
    end
  end
end

class ServerSentEvents < Reel::Server
#  include Celluloid::Logger
  include Celluloid::Notifications
  
  def initialize(ip = '127.0.0.1', port = 63310)
    @connections = []
    @history = []
    @lastMessageId = 0
    async.ping
    subscribe(/.*/, :broadcast)
    super(ip, port, &method(:on_connection))
  end

  def broadcast(event, data)
    #only keep the last 5000 Events
    if @history.size >= 6000
      @history.slice!(0, @history.size - 1000)
    end
    @lastMessageId += 1
    @history << {id: @lastMessageId, event: event, data: data}
    @connections.each do |socket|
      async.send_sse(socket, data, event, @lastMessageId)
    end
    true
  end

  private
  #event and id are optional
  def send_sse(socket, data, event = nil, id = nil)
    begin
      socket.id id if id
      socket.event event if event
      socket.data data
    rescue
      @connections.delete(socket)
    end
  end

  def send_ping
    @connections.each do |socket|
      begin
        #Lines that start with a Colon are Comments and will be ignored
        socket << ":\n"
      rescue
        @connections.delete(socket)
      end
    end
  end

  def ping
    #apache 2.2 closes connections after five seconds when nothing is send
    every(5) do
      send_ping
    end
  end

  def handle_request(request)
    query = {}
    (request.query_string || '').split('&').each do |kv|
      key, value = kv.split('=')
      if key && value
        key, value = CGI.unescape(key), CGI.unescape(value)
        query[key] = value
      end
    end
    body = Reel::EventStream.new do |socket|
      @connections << socket
      socket.retry 5000
      #after a Connection reset resend newer Messages to the Client
      if @history.count > 0 && id = (request.headers['Last-Event-ID'] || query['lastEventId'])
        begin
          id = Integer(id)
          if history = @history.select {|h| h[:id] >= id}.map {|a| "id: %d\nevent: %s\ndata: %s" % [a[:id], a[:event], a[:data]]}.join("\n\n")
            socket << "%s\n\n" % [history]
          else
            socket << "id\n\n"
          end
        rescue
          @connections.delete(socket)
          request.close
        end
      else
        socket << "id\n\n"
      end
    end
    #X-Accel-Buffering is nginx(?) specific. Setting this to "no" will allow unbuffered responses suitable for Comet and HTTP streaming applications
    request.respond Reel::StreamResponse.new(:ok, {
      'Content-Type' => 'text/event-stream; charset=utf-8',
      'Cache-Control' => 'no-cache',
      'X-Accel-Buffering' => 'no',
      'Access-Control-Allow-Origin' => '*'}, body)
  end

  def on_connection(connection)
    connection.each_request do |request|
      handle_request(request)
    end
  end
end

TimePusher.new
ServerSentEvents.run
