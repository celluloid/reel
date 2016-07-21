require 'spec_helper'
require 'reel/request/multipart'
require 'net/http'

RSpec.describe Reel::Request::Multipart do

  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }
  let(:txt_filepath){ 'spec/support/multipart_test_example.txt' }
  let(:img_path){'logo.png'}

  EOL = "\r\n".freeze
  MULTIPART_BOUNDARY = "Myboundary".freeze
  PART_NAME = "datafile".freeze

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
        expect(req.multipart[PART_NAME][:ended]).to eq true
        expect(req.multipart[PART_NAME][:data]).to eq File.read(txt_filepath)

        req.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do

      post_body = []
      post_body << "--#{MULTIPART_BOUNDARY}#{EOL}"
      post_body << "Content-Disposition: form-data; name=\"#{PART_NAME}\"; filename=\"#{File.basename(txt_filepath)}\"#{EOL}"
      post_body << "Content-Type: text/plain#{EOL}"
      post_body << EOL
      post_body << File.read(txt_filepath)
      post_body << "#{EOL}--#{MULTIPART_BOUNDARY}--#{EOL}"

      http = Net::HTTP.new(endpoint.host, endpoint.port)
      request = Net::HTTP::Post.new(endpoint.request_uri)
      request.body = post_body.join
      request["Content-Type"] = "multipart/form-data, boundary=#{MULTIPART_BOUNDARY}"

      http.request(request)
    end

    raise ex if ex
  end

  it "Parses data from image uploaded" do
    ex = nil

    handler = proc do |connection|
      begin
        req = connection.request
        expect(req.multipart? req.body).to eq true
        expect(req.multipart.empty?).to eq false
        expect(req.multipart[PART_NAME][:ended]).to eq true
        expect(req.multipart[PART_NAME][:data]).to eq IO.binread(img_path)

        req.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do

      post_body = []
      post_body << "--#{MULTIPART_BOUNDARY}#{EOL}"
      post_body << "Content-Disposition: form-data; name=\"#{PART_NAME}\"; filename=\"#{File.basename(img_path)}\"#{EOL}"
      post_body << "Content-Type: application/octet-stream#{EOL}"
      post_body << EOL
      post_body << IO.binread(img_path)
      post_body << "#{EOL}--#{MULTIPART_BOUNDARY}--#{EOL}"

      http = Net::HTTP.new(endpoint.host, endpoint.port)
      request = Net::HTTP::Post.new(endpoint.request_uri)
      request.body = post_body.join
      request["Content-Type"] = "multipart/form-data, boundary=#{MULTIPART_BOUNDARY}"

      http.request(request)

    end

    raise ex if ex
  end

end
