require 'spec_helper'

describe Reel::RackWorker do
  let(:endpoint) { URI(example_url) }

  RackApp = Proc.new do |env|
    [200, {'Content-Type' => 'text/plain'}, ['Hello rack world!']]
  end

  let(:worker) do
    handler = Rack::Handler::Reel.new
    handler.options[:app] = RackApp

    Reel::RackWorker.new(handler)
  end

  it "creates a rack env from a request" do
    with_socket_pair do |client, connection|
      client << ExampleRequest.new(:get, '/test?hello=true').to_s
      request = connection.request
      env = worker.request_env(request, connection)

      Reel::RackWorker::PROTO_RACK_ENV.each do |k, v|
        env[k].should == v
      end

      env["SERVER_NAME"].should == 'www.example.com'
      env["SERVER_PORT"].should == "3000"
      env["REMOTE_ADDR"].should == "127.0.0.1"
      env["PATH_INFO"].should == "/test"
      env["REQUEST_METHOD"].should == "GET"
      env["QUERY_STRING"].should == "hello=true"
      env["HTTP_HOST"].should == 'www.example.com'
      env["HTTP_ACCEPT_LANGUAGE"].should == "en-US,en;q=0.8"

      env["rack.input"].should be_kind_of(StringIO)
      env["rack.input"].string.should == ''

      validator = ::Rack::Lint.new(RackApp)
      status, *rest = validator.call(env)
      status.should == 200
    end
  end

  context "WebSocket" do
    include WebSocketHelpers

    it "places websocket into rack env" do
      with_socket_pair do |client, connection|
        client << handshake.to_data
        request = connection.request
        env = worker.websocket_env(request)
        
        env["REMOTE_ADDR"].should == "127.0.0.1"
        env["rack.websocket"].should be_a Reel::WebSocket
      end
    end    
  end

  it "delegates web requests to the rack app" do
    ex = nil

    handler = proc do |connection|
      begin
        worker.handle!(connection.detach)
      rescue => ex
      end
    end

    with_reel(handler) do
      http = Net::HTTP.new(endpoint.host, endpoint.port)
      request = Net::HTTP::Get.new(endpoint.request_uri)
      response = http.request(request)
      response.should be_a Net::HTTPOK
      response.body.should == 'Hello rack world!'
    end

    raise ex if ex
  end
end
