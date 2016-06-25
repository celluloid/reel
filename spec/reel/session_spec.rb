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
  let(:crypto){Class.new {
    include Reel::Session::Crypto
    def initialize
      @config ={
        :secret_key => 'temp1',
        :session_name => 'temp2'
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

  it "ensure escaping the unsafe character while using AES128" do
    value = "Original"
    cipher = OpenSSL::Cipher::AES128.new :CBC
    cipher.encrypt
    cipher.key = key
    cipher.iv = iv
    encrypt = Base64.encode64(cipher.update(value) + cipher.final)
    expect(encrypt).to match unsafe
    expect(URI.encode_www_form_component encrypt).to_not match unsafe
  end

  it "encryption/decryption are performing well" do
    original_value = "test"
    c = crypto.new
    expect(c.decrypt c.encrypt original_value).to eq original_value
    encrypt_val = c.encrypt original_value
    c.config[:secret_key] = "change"
    expect(c.decrypt encrypt_val).to_not eq original_value
  end
end
