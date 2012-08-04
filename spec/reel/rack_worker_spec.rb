require 'spec_helper'

describe Reel::RackWorker do

  class MockConnection < Reel::Connection
    attr_reader :response

    def respond(response, headers_or_body = {}, body = nil)
      @response = response
    end
  end

  let :config do
    app = Proc.new do |env|
      [200, {'Content-Type' => 'text/plain'}, ['Hello world!']]
    end

    config = Reel::Configuration.new
    config.options[:app] = app

    config
  end

  let(:worker) { Reel::RackWorker.new(config) }

  it "creates a rack env from a request" do
    with_request do |request, connection|
      env = worker.rack_env(request, connection)

      Reel::RackWorker::PROTO_RACK_ENV.each do |k, v|
        env[k].should == v
      end

      env["SERVER_NAME"].should == '0.0.0.0'
      env["SERVER_PORT"].should == 3000
      env["REMOTE_ADDR"].should == "127.0.0.1"
      env["REMOTE_HOST"].should == "127.0.0.1"
      env["PATH_INFO"].should == "/test"
      env["REQUEST_METHOD"].should == "GET"
      env["REQUEST_PATH"].should == "/test"
      env["ORIGINAL_FULLPATH"].should == "/test"
      env["QUERY_STRING"].should == "hello=true"
      env["HTTP_HOST"].should == 'example.com:3000'
      env["HTTP_ACCEPT_LANGUAGE"].should == 'es-ES,es;q=0.8'
      env["REQUEST_URI"].should == 'http://example.com:3000/test'

      env["rack.input"].should be_kind_of(StringIO)
      env["rack.input"].string.should == ''
    end
  end

  it "delegates web requests to the rack app" do
    with_request do |request, connection|

      worker.handle(request, connection)

      response = connection.response

      response.status.should  == 200
      response.headers.should == {"Content-Type"=>"text/plain", "Content-Length"=>12}
      response.body.should    == "Hello world!"
    end
  end


  def with_request
    host = '127.0.0.1'
    port = 10103

    @server = TCPServer.new(host, port)
    @client = TCPSocket.new(host, port)

    begin
      peer   = @server.accept
      connection = MockConnection.new(peer)

      headers = {
        'Accept-Language' => 'es-ES,es;q=0.8',
        'Host'            => 'example.com:3000'
      }

      request = Reel::Request.new(:get, "/test?hello=true", "1.1", headers, connection)

      yield request, connection
    ensure
      @server.close
      @client.close
    end
  end
end