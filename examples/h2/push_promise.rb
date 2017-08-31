#!/usr/bin/env ruby
# frozen_string_literal: true
# Run with: bundle exec examples/h2/push_promise.rb

require 'bundler/setup'
require 'reel/h2'

Reel::Logger.logger.level = ::Logger::DEBUG
Reel::H2.verbose!

port         = 1234
addr         = Socket.getaddrinfo('localhost', port).first[3]
certs_dir    = File.expand_path '../../../tmp/certs', __FILE__
logo_png     = File.read File.expand_path '../../../logo.png', __FILE__
push_promise = '<html>wait for it...<img src="/logo.png"/><script src="/pushed.js"></script></html>'
pushed_js    = '(()=>{ alert("hello h2 push promise!"); })();'

sni = {
  'localhost' => {
    :cert => certs_dir + '/server.crt',
    :key  => certs_dir + '/server.key',
    # :extra_chain_cert => certs_dir + '/chain.pem'
  }
}

puts "*** Starting server on https://#{addr}:#{port}"
s = Reel::H2::Server::HTTPS.new host: addr, port: port, sni: sni do |connection|
  connection.each_stream do |stream|

    if stream.request.path == '/favicon.ico'
      stream.respond :not_found

    else
      stream.goaway_on_complete

      stream.push_promise '/logo.png', { 'content-type' => 'image/png' }, logo_png

      js_promise = stream.push_promise_for '/pushed.js', { 'content-type' => 'application/javascript' }, pushed_js
      js_promise.make_on stream

      stream.respond :ok, push_promise

      js_promise.keep
    end
  end
end

sleep
