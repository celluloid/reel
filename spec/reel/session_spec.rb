require 'spec_helper'
require 'reel/session'
require 'net/http'

RSpec.describe Reel::Session do

  it "include module properly" do
    with_socket_pair do |client,peer|
      connection = Reel::Connection.new(peer)
      client << ExampleRequest.new.to_s
      request = connection.request
      expect(request).to respond_to :session
      expect(request).to respond_to :configuration
      expect(request).to respond_to :initialize_session
      expect(request).to respond_to :finalize_session
    end
  end

  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }

  it "receives HTTP requests and sends responses with sessions activated" do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        expect(request.method).to eq 'GET'
        expect(request.version).to eq "1.1"
        expect(request.url).to eq example_path
        expect(request.session).to be_a_kind_of Hash
        request.session[:test] = "ok"
        expect(request.session).to eq Hash[:test,"ok"]
        connection.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do
      res = Net::HTTP.get endpoint
    end

    raise ex if ex
  end

  it "Checks if session handler are working" do
    ex = nil

    handler = proc do |connection|
      begin
        req = connection.request
        if req.session[:foo] == 'bar'
          req.session.clear
          expect(req.session).to eq Hash.new
        else
          req.session[:foo] = 'bar'
          expect(req.session).to eq Hash[:foo,'bar']
        end

        connection.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do
      Net::HTTP.get endpoint
    end

    raise ex if ex
  end
end
