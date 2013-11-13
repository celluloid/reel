require 'spec_helper'
require 'net/http'

describe Reel::Server::UNIX do
  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }

  it 'allows connections over UNIX sockets' do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        request.method.should eq 'GET'
        connection.respond :ok, request.body.to_s
      rescue => ex
      end
    end

    Dir::Tmpname.create('reel-sock') do |path|
      begin
        server  = Reel::Server::UNIX.new(path, &handler)
        sock    = Net::BufferedIO.new Celluloid::IO::UNIXSocket.new(path)
        request = Net::HTTP::Get.new('/')

        request.exec(sock, '1.1', path)
      ensure
        server.terminate if server && server.alive?
      end
    end

  end
end
