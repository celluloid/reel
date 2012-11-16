require 'spec_helper'

describe Reel::RackWorker do
  let(:endpoint) { URI(example_url) }

  let(:worker) do
    app = Proc.new do |env|
      [200, {'Content-Type' => 'text/plain'}, ['Hello world!']]
      [200, {'Content-Type' => 'text/plain'}, ['Hello rack world!']]
    end

    handler = Rack::Handler::Reel.new
    handler.options[:app] = app

    Reel::RackWorker.new(handler)
  end

  it "creates a rack env from a request" do
    with_socket_pair do |client, connection|
      client << ExampleRequest.new(:get, '/test?hello=true').to_s
      request = connection.request
      env = worker.rack_env(request, connection)

      Reel::RackWorker::PROTO_RACK_ENV.each do |k, v|
        env[k].should == v
      end

      env["SERVER_NAME"].should == 'www.example.com'
      env["SERVER_PORT"].should == "3000"
      env["REMOTE_ADDR"].should == "127.0.0.1"
      env["PATH_INFO"].should == "/test"
      env["REQUEST_METHOD"].should == "GET"
      env["REQUEST_PATH"].should == "/test"
      env["ORIGINAL_FULLPATH"].should == "/test"
      env["QUERY_STRING"].should == "hello=true"
      env["HTTP_HOST"].should == 'www.example.com'
      env["HTTP_ACCEPT_LANGUAGE"].should == "en-US,en;q=0.8"
      env["REQUEST_URI"].should == '/test'

      %w(localhost 127.0.0.1).should include env["REMOTE_HOST"]

      env["rack.input"].should be_kind_of(StringIO)
      env["rack.input"].string.should == ''
    end
  end

  context "WebSocket" do
    include WebSocketHelpers

    it "places websocket into rack env" do
      with_socket_pair do |client, connection|
        client << handshake.to_data
        request = connection.request
        env = worker.rack_env(request, connection)
        
        env["rack.websocket"].should == request
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
