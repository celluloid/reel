require 'spec_helper'
require 'reel/request/multipart'
require 'net/http'

RSpec.describe Reel::Request::Multipart do

  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }
  let(:filepath){ 'spec/support/multipart_test_example.txt' }
  let(:part_name){ 'datafile' }

  it "check if request is a multipart or not" do
    ex = nil

    handler = proc do |connection|
      begin
        req = connection.request
        expect(req.multipart).to eq nil
        expect(req.multipart? req.body).to eq false
        req.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do
      Net::HTTP.new(endpoint.host,endpoint.port).get endpoint
    end

    raise ex if ex
  end

  it "Parses data from file uploaded if request body is multipart type" do
    ex = nil

    handler = proc do |connection|
      begin
        req = connection.request
        expect(req.multipart? req.body).to eq true
        expect(req.multipart.empty?).to eq false
        expect(req.multipart[part_name][:ended]).to eq true
        expect(req.multipart[part_name][:data]).to eq File.read(filepath)

        req.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do
      BOUNDARY = "Myboundary"

      post_body = []
      post_body << "--#{BOUNDARY}\r\n"
      post_body << "Content-Disposition: form-data; name=\"#{part_name}\"; filename=\"#{File.basename(filepath)}\"\r\n"
      post_body << "Content-Type: text/plain\r\n"
      post_body << "\r\n"
      post_body << File.read(filepath)
      post_body << "\r\n--#{BOUNDARY}--\r\n"

      http = Net::HTTP.new(endpoint.host, endpoint.port)
      request = Net::HTTP::Post.new(endpoint.request_uri)
      request.body = post_body.join
      request["Content-Type"] = "multipart/form-data, boundary=#{BOUNDARY}"

      http.request(request)
    end

    raise ex if ex
  end

end
