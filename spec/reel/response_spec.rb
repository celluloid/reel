require 'spec_helper'

describe Reel::Response do
  it "streams enumerables" do
    with_socket_pair do |client, connection|
      client << ExampleRequest.new.to_s
      request = connection.request

      connection.respond Reel::Response.new(:ok, ["Hello", "World"])
      connection.close

      response = client.read(4096)
      crlf = Reel::Response::Writer::CRLF
      fixture = "5#{crlf}Hello#{crlf}5#{crlf}World#{crlf}0#{crlf*2}"
      response[(response.length - fixture.length)..-1].should eq fixture
    end
  end
end
