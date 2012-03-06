require 'spec_helper'
require 'net/http'

describe Reel::Server do
  let(:endpoint) { URI("http://#{example_addr}:#{example_port}#{example_url}") }
  let(:response_body) { "ohai thar" }
  
  it "receives HTTP requests and sends responses" do
    handler_called = false
    handler = proc do |connection|
      handler_called = true
      request = connection.request
      request.method.should eq :get
      request.version.should eq "1.1"
      request.url.should eq example_url
      
      connection.respond :ok, response_body
    end
    
    with_reel(handler) do
      response = Net::HTTP.get endpoint
      response.should eq response_body
    end
    
    handler_called.should be_true
  end
  
  it "echoes request bodies as response bodies" do
    handler_called = false
    handler = proc do |connection|
      handler_called = true
      request = connection.request
      request.method.should eq :post
      connection.respond :ok, request.body
    end
    
    with_reel(handler) do
      http = Net::HTTP.new(endpoint.host, endpoint.port)
      request = Net::HTTP::Post.new(endpoint.request_uri)
      request['connection'] = 'close'
      request.body = response_body
      response = http.request(request)
      response.should be_a Net::HTTPOK
      response.body.should == response_body
    end
    
    handler_called.should be_true
  end
end