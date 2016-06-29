require 'spec_helper'
require 'reel/session'
require 'net/http'
require 'openssl'
require 'base64'
require 'uri'

RSpec.describe Reel::Session do

  before(:all) do
    Reel::Session.configuration({:session_length=>1})
  end

  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }
  let(:key){"12345678901234567"}
  let(:iv){"1234567890123456"}
  let(:unsafe){/[^\-_.!~*'()a-zA-Z\d\/?:@&+$%,\[\]]/}
  let(:crypto){Class.new {
    include Reel::Session::Crypto
    def initialize
      @config ={
        :secret_key => Reel::Session.configuration[:secret_key],
        :session_name => Reel::Session.configuration[:session_name]
      }
    end
    attr_accessor :config
    }
  }

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

  it "Donot generate uuid/store in outer hash for empty session value" do
    ex = nil

    handler = proc do |connection|
      begin
        req = connection.request
        unless req.session.empty?
          req.session.clear
        end
        expect(req.session.empty?).to eq true
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
      c = crypto.new
      key = c.decrypt ((resp['set-cookie'].split(';').first.split('='))[1])
      expect(key).to_not eq nil
      expect(Reel::Session.store.key? key).to eq true
      sleep 1
      expect(Reel::Session.store.key? key).to eq false
    end

    raise ex if ex
  end

  it "ensure escaping the unsafe character while using AES128" do
    value = "Original"
    c = crypto.new
    encrypted = c.encrypt(value)
    expect(encrypted).to_not match unsafe
    expect(URI.decode_www_form_component encrypted).to match unsafe
  end

  it "encryption/decryption are performing well" do
    original_value = "test"
    c = crypto.new
    expect(c.decrypt c.encrypt original_value).to eq original_value
    encrypt_val = c.encrypt original_value
    orig_key = c.config[:secret_key]
    c.config[:secret_key] = "change"
    expect(c.decrypt encrypt_val).to_not eq original_value
    # correcting config for other test
    c.config[:secret_key] = orig_key
    c.change_config
  end

end
