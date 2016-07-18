require 'spec_helper'
require 'reel/session'
require 'net/http'

RSpec.describe Reel::Session do

  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }

  it "receives HTTP requests and sends responses with sessions activated" do
    ex = nil

    handler = proc do |connection|
      Reel::Session.configuration(connection.server,{:session_length=>1})
      begin
        request = connection.request
        expect(request.method).to eq 'GET'
        expect(request.version).to eq "1.1"
        expect(request.url).to eq example_path
        expect(request.session).to be_a_kind_of Hash
        request.session[:test] = "ok"
        expect(request.session).to eq({:test=>"ok"})
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
      Reel::Session.configuration(connection.server,{:session_length=>1})
      begin
        req = connection.request
        if req.session.empty?
          req.session[:foo] = 'bar'
          expect(req.session).to eq({:foo=>'bar'})
        else
          req.session.clear
          expect(req.session.empty?).to eq true
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
      expect(resp['set-cookie']).to_not eq nil
    end

    raise ex if ex
  end

  it "generate uuid and set it properly in header/store it in hash if has some session value" do
    ex = nil

    handler = proc do |connection|
      Reel::Session.configuration(connection.server,{:session_length=>1})
      begin
        req = connection.request
        if req.session.empty?
          req.session[:foo] = 'bar'
        end
        expect(req.session.empty?).to eq false

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

  it "Deleting timers are deleting session value after expiry" do
    ex = nil

    handler = proc do |connection|
      Reel::Session.configuration(connection.server,{:session_length=>0.01})
      begin
        req = connection.request
        if req.session.empty?
          req.session[:foo] = 'bar'
        end
        req.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do
      resp = Net::HTTP.new(endpoint.host,endpoint.port).get endpoint
      expect(resp['set-cookie']).to_not eq nil
      key = (resp['set-cookie'].split(';').first.split('='))[1]
      expect(key).to_not eq nil
      expect(Reel::Session.store.key? key).to eq true
      sleep 0.01
      expect(Reel::Session.store.key? key).to eq false
    end

    raise ex if ex
  end

  it "For different mock servers, making sure that different configuration hashes are kept" do
       with_socket_pair do |client, peer|
         server1 = Object.new
         server2 = Object.new

         Reel::Session.configuration(server2,{:session_name=>"change"})

         config1 = Reel::Session::DEFAULT_CONFIG
         config2 = Reel::Session::DEFAULT_CONFIG.merge({:session_name=>"change"})

         expect(Reel::Session.configuration(server1)).to eq config1
         expect(Reel::Session.configuration(server2)).to eq config2
       end
  end
end
