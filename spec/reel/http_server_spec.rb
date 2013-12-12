require 'spec_helper'
require 'net/http'

describe Reel::Server::HTTP do
  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }

  it "receives HTTP requests and sends responses" do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        request.method.should eq 'GET'
        request.version.should eq "1.1"
        request.url.should eq example_path

        connection.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do
      response = Net::HTTP.get endpoint
      response.should eq response_body
    end

    raise ex if ex
  end

  it "echoes request bodies as response bodies" do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        request.method.should eq 'POST'
        connection.respond :ok, request.body.to_s
      rescue => ex
      end
    end

    with_reel(handler) do
      http = Net::HTTP.new(endpoint.host, endpoint.port)
      request = Net::HTTP::Post.new(endpoint.request_uri)
      request['connection'] = 'close'
      request.body = response_body
      response = http.request(request)
      response.should be_a Net::HTTPOK
      response.body.should == response_body
    end

    raise ex if ex
  end
end
