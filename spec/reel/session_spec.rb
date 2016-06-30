require 'spec_helper'
require 'reel/session'
require 'net/http'
require 'openssl'
require 'base64'
require 'uri'

RSpec.describe Reel::Session do

  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }
  let(:key){"12345678901234567"}
  let(:iv){"1234567890123456"}
  let(:unsafe){/[^\-_.!~*'()a-zA-Z\d\/?:@&+$%,\[\]]/}
  let(:crypto_config){
    {
        :secret_key => Reel::Session.configuration('test')[:secret_key],
        :session_name => Reel::Session.configuration('test')[:session_name]
    }
  }

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
      expect(resp['set-cookie']).to eq nil
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
      Reel::Session.configuration(connection.server,{:session_length=>1})
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
      c = Reel::Session::Crypto
      key = c.decrypt((resp['set-cookie'].split(';').first.split('='))[1],crypto_config)
      expect(key).to_not eq nil
      expect(Reel::Session.store.key? key).to eq true
      sleep 1
      expect(Reel::Session.store.key? key).to eq false
    end

    raise ex if ex
  end

  it "ensure escaping the unsafe character while using AES128" do
    value = "Original"
    c = Reel::Session::Crypto
    encrypted = c.encrypt(value,crypto_config)
    expect(encrypted).to_not match unsafe
    expect(URI.decode_www_form_component encrypted).to match unsafe
  end

  it "encryption/decryption are performing well" do
    original_value = "test"
    c = Reel::Session::Crypto
    expect(c.decrypt(c.encrypt(original_value,crypto_config),crypto_config)).to eq original_value
    encrypt_val = c.encrypt(original_value,crypto_config)
    changed_config = crypto_config.merge({:secret_key=>"change"})
    expect(c.decrypt(encrypt_val,changed_config)).to_not eq original_value
  end

end
