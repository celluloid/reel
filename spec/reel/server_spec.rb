require 'spec_helper'
require 'net/http'

describe Reel::Server do
  let(:endpoint) { "http://#{example_addr}:#{example_port}#{example_url}" }
  let(:response_body) { "ohai thar" }
  
  it "receives HTTP requests and sends responses" do
    handler_called = false
    handler = proc do |connection|
      request = connection.request
      request.method.should eq :get
      request.version.should eq "1.1"
      request.url.should eq example_url
      
      connection.respond Reel::Response.new(:ok, response_body)
      handler_called = true
    end
    
    with_reel(handler) do
      response = Net::HTTP.get URI(endpoint)
      response.should eq response_body
      handler_called.should be_true
    end
  end
end