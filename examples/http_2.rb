#!/usr/bin/env ruby

require 'reel'
require 'pry'

RES = ''.freeze

LOG = Celluloid.logger

LOG.info "Listening on 127.0.0.1:4567..."

Reel::Connection::HTTP2.on :stream do |s|

  LOG.info "http2 headers: #{s[:headers]}"
  LOG.info "http2 body: #{s[:body]}"

  res = [
    "hi there.",
    "how's it going?",
    "yay!"
  ]

  s[:stream].headers({
    ':status' => '200',
    'content-length' => res.join(nil).bytesize.to_s,
    'content-type' => 'text/plain',
  }, end_stream: false)

  s[:stream].data res[0], end_stream: false
  Celluloid.sleep 3
  s[:stream].data res[1], end_stream: false
  Celluloid.sleep 1
  s[:stream].data res[2]

end

Reel::Server::HTTP.run('127.0.0.1', 4567) do |http_1_connection|

  http_1_connection.each_request do |request|
    LOG.info request.inspect
    request.respond :ok, RES
  end

end
