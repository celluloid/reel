require 'spec_helper'

RSpec.describe Reel::Response do
  it "streams enumerables" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      client << ExampleRequest.new.to_s
      request = connection.request

      connection.respond Reel::Response.new(:ok, ["Hello", "World"])
      connection.close

      response = client.read(4096)
      crlf = Reel::Response::Writer::CRLF
      fixture = "5#{crlf}Hello#{crlf}5#{crlf}World#{crlf}0#{crlf*2}"
      expect(response[(response.length - fixture.length)..-1]).to eq fixture
    end
  end

  it "canonicalizes response headers" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      client << ExampleRequest.new.to_s
      request = connection.request

      connection.respond Reel::Response.new(:ok, {"content-type" => "application/json"}, "['mmmkay']")
      connection.close

      response = client.read(4096)
      expect(response["Content-Type: application/json"]).to_not be_nil
    end
  end
end
