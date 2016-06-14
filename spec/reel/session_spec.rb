require 'spec_helper'
require 'reel/session'
require 'net/http'

RSpec.describe Reel::Session do

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
        request.respond :ok, response_body
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
        if req.session.empty?
          expect(req.session).to eq Hash.new
          req.session[:foo] = 'bar'
          expect(req.session).to eq Hash[:foo,'bar']
        else
          expect(req.session).to eq Hash[:foo,'bar']
          req.session.clear
          expect(req.session).to eq Hash.new
        end

        req.respond :ok, response_body
        rescue => ex
      end
    end

    with_reel(handler) do
      resp = Net::HTTP.new(endpoint.host,endpoint.port).get endpoint
      expect(resp['set-cookie']).to_not eq nil
      temp = resp['set-cookie'].split(';').first
      headers = {
          'Cookie' => temp
      }
      resp = Net::HTTP.new(endpoint.host,endpoint.port).get(endpoint.path,headers)
      expect(resp['set-cookie']).to eq nil
    end

    raise ex if ex
  end

  it "Donot generate uuid/store in outer hash for empty session value" do
    ex = nil

    handler = proc do |connection|
      begin
        req = connection.request
        if req.session
          req.session.clear
        end

        req.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do
      resp = Net::HTTP.new(endpoint.host,endpoint.port).get endpoint
      expect(resp['set-cookie']).to eq nil
    end

    raise ex if ex
  end

  it "generate uuid and set it properly in header/store it in hash if has some session value" do
    ex = nil

    handler = proc do |connection|
      begin
        req = connection.request
        if req.session.empty?
          req.session[:foo] = 'bar'
        end
        expect(req.session).to_not eq nil

        req.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do
      resp = Net::HTTP.new(endpoint.host,endpoint.port).get endpoint
      expect(resp['set-cookie']).to_not eq nil
      temp = resp['set-cookie'].split(';').first
      headers = {
          'Cookie' => temp
      }
      resp = Net::HTTP.new(endpoint.host,endpoint.port).get(endpoint.path,headers)
      expect(resp['set-cookie']).to_not eq nil
    end

    raise ex if ex
  end
end
