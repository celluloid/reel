require 'spec_helper'
require 'net/http'

return unless !defined? JRUBY_VERSION

RSpec.describe Reel::Server::UNIX do
  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }

  it 'allows connections over UNIX sockets' do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        expect( request.method ).to eq 'GET'
        connection.respond :ok, self.response_body
      end
    end

    Dir::Tmpname.create('reel-sock') do |path|
      begin
        server  = Reel::Server::UNIX.new(path, &handler)
        sock    = Net::BufferedIO.new Celluloid::IO::UNIXSocket.new(path)
        request = Net::HTTP::Get.new('/')

        request.exec(sock, '1.1', path)
        response = Net::HTTPResponse.read_new(sock)
        response.reading_body(sock, request.response_body_permitted?) { }

        expect(response.body).to eq(self.response_body)
      ensure
        server.terminate if server && server.alive?
      end
    end

    raise ex if ex
  end
end
