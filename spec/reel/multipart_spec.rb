require 'spec_helper'
require 'reel/request/multipart'
require 'net/http'

RSpec.describe Reel::Request::Multipart do

  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }
  let(:txt_filepath){ 'spec/support/multipart_test_example.txt' }
  let(:img_path){'logo.png'}
  let(:part_name){ 'datafile' }
  let(:boundary){"Myboundary"}

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
        expect(req.multipart[part_name][:data]).to eq File.read(txt_filepath)

        req.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do

      post_body = []
      post_body << "--#{boundary}\r\n"
      post_body << "Content-Disposition: form-data; name=\"#{part_name}\"; filename=\"#{File.basename(txt_filepath)}\"\r\n"
      post_body << "Content-Type: text/plain\r\n"
      post_body << "\r\n"
      post_body << File.read(txt_filepath)
      post_body << "\r\n--#{boundary}--\r\n"

      http = Net::HTTP.new(endpoint.host, endpoint.port)
      request = Net::HTTP::Post.new(endpoint.request_uri)
      request.body = post_body.join
      request["Content-Type"] = "multipart/form-data, boundary=#{boundary}"

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
        expect(req.multipart[part_name][:ended]).to eq true
        expect(req.multipart[part_name][:data]).to eq IO.binread(img_path)

        req.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do

      post_body = []
      post_body << "--#{boundary}\r\n"
      post_body << "Content-Disposition: form-data; name=\"#{part_name}\"; filename=\"#{File.basename(img_path)}\"\r\n"
      post_body << "Content-Type: application/octet-stream\r\n"
      post_body << "\r\n"
      post_body << IO.binread(img_path)
      post_body << "\r\n--#{boundary}--\r\n"

      http = Net::HTTP.new(endpoint.host, endpoint.port)
      request = Net::HTTP::Post.new(endpoint.request_uri)
      request.body = post_body.join
      request["Content-Type"] = "multipart/form-data, boundary=#{boundary}"

      http.request(request)

    end

    raise ex if ex
  end

end
