require 'spec_helper'
require 'reel/app'

describe Reel::App do
  let(:client_cert) { OpenSSL::X509::Certificate.new fixture_dir.join("client.crt").read }
  let(:client_key)  { OpenSSL::PKey::RSA.new fixture_dir.join("client.key").read }
  let(:client_context) do
    OpenSSL::SSL::SSLContext.new.tap do |context|
      context.cert = client_cert
      context.key  = client_key
    end
  end

  let(:server_cert) { OpenSSL::X509::Certificate.new fixture_dir.join("server.crt").read }
  let(:server_key)  { OpenSSL::PKey::RSA.new fixture_dir.join("server.key").read }
  let(:server_context) do
    OpenSSL::SSL::SSLContext.new.tap do |context|
      context.cert = server_cert
      context.key  = server_key
    end
  end

  let(:app) {
    Class.new do
      include Reel::App

      get example_path do
        [200, {}, "hello foo"]
      end

    end
  }

  before(:each) do
    @app = app.new(example_addr, example_port, server_context)
  end

  after(:each) do
    @app.server.terminate if @app && @app.server.alive?
  end

  it 'responds to get requests' do
    res = Http.with_response(:object).get example_url
    res.status.should == 200
    res.headers.should == {"Content-Length" => res.body.length.to_s}
    res.body.should == "hello foo"
  end

  it 'terminates the server' do
    @app.terminate
    @app.server.should_not be_alive
  end
end
