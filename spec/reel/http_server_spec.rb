require 'spec_helper'
require 'net/http'

RSpec.describe Reel::Server::HTTP do
  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }

  it "receives HTTP requests and sends responses" do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        expect(request.method).to eq 'GET'
        expect(request.version).to eq "1.1"
        expect(request.url).to eq example_path

        connection.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do
      response = Net::HTTP.get endpoint
      expect(response).to eq response_body
    end

    raise ex if ex
  end

  it "echoes request bodies as response bodies" do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        expect(request.method).to eq 'POST'
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
      expect(response).to be_a Net::HTTPOK
      expect(response.body).to eq(response_body)
    end

    raise ex if ex
  end
end
