#!/usr/bin/env ruby
# frozen_string_literal: true
# Run with: bundle exec examples/h2/https_hello_world.rb

require 'bundler/setup'
require 'reel/h2'

addr, port = '127.0.0.1', 1234
certs_dir  = File.expand_path '../../../tmp/certs', __FILE__

sni = {
  '127.0.0.1' => {
    :cert => certs_dir + '/server.crt',
    :key  => certs_dir + '/server.key',
    # :extra_chain_cert => certs_dir + '/chain.pem'
  }
}

puts "*** Starting server on https://#{addr}:#{port}"
s = Reel::H2::Server::HTTPS.new host: addr, port: port, sni: sni do |connection|
  connection.each_stream do |stream|
    stream.respond :ok, "hello, world!\n"
    connection.goaway
  end
end

sleep
