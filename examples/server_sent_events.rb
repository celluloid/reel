#!/usr/bin/env ruby
# See: http://www.w3.org/TR/eventsource/
# Run with: bundle exec examples/server_sent_events.rb
# Test with: curl -vNH 'Accept: text/event-stream' -H 'Last-Event-ID: 1' -H 'Cache-Control: no-cache' http://localhost:63310

require 'bundler/setup'
require 'time'
require 'reel'


class ServerSentEvents < Reel::Server::HTTP
  include Celluloid::Logger
  
  def initialize(ip = '127.0.0.1', port = 63310)
    @connections = []
    @history = []
    @lastEventId = 0
    async.ping
    async.ring #not needed for Production, only to have some events here.
    super(ip, port, &method(:on_connection))
  end

  #broadcasts events to all clients
  def broadcast(event, data)
    #only keep the last 5000 Events
    if @history.size >= 6000
      @history.slice!(0, @history.size - 1000)
    end
    @lastEventId += 1
    @history << {id: @lastEventId, event: event, data: data}
    info "Sending Event: #{event} Data: #{data} to #{@connections.count} Clients"
    @connections.each do |socket|
      async.send_sse(socket, data, event, @lastEventId)
    end
    true
  end

  private
  #event and id are optional, Eventsource only needs data
  def send_sse(socket, data, event = nil, id = nil)
    begin
      socket.id id if id
      socket.event event if event
      socket.data data
    rescue Reel::SocketError, NoMethodError
      @connections.delete(socket) if @connections.include?(socket)
    end
  end

  #Lines that start with a Colon are Comments and will be ignored
  def send_ping
    @connections.each do |socket|
      begin
        socket << ":\n"
      rescue Reel::SocketError
        @connections.delete(socket)
      end
    end
  end

  #apache 2.2 closes connections after five seconds when nothing is send, see this as a poor mans Keep-Alive
  def ping
    every(5) do
      send_ping
    end
  end

  #only used to have some events here, not needed for Production.
  def ring
    every(2) do
      broadcast(:time, Time.now.httpdate)
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
    #see https://github.com/celluloid/reel/blob/master/lib/reel/stream.rb#L35
    eventStream = Reel::EventStream.new do |socket|
      @connections << socket
      socket.retry 5000
      #after a Connection reset resend newer Messages to the Client, query['lastEventId'] is needed for https://github.com/Yaffle/EventSource
      if @history.count > 0 && id = (request.headers['Last-Event-ID'] || query['lastEventId'])
        begin
          if history = @history.select {|h| h[:id] >= Integer(id)}.map {|a| "id: %d\nevent: %s\ndata: %s" % [a[:id], a[:event], a[:data]]}.join("\n\n")
            socket << "%s\n\n" % [history]
          else
            socket << "id\n\n"
          end
        rescue ArgumentError, Reel::SocketError
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
      'Access-Control-Allow-Origin' => '*'}, eventStream)
  end

  def on_connection(connection)
    connection.each_request do |request|
      handle_request(request)
    end
  end
end

ServerSentEvents.run
