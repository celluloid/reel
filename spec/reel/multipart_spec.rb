require 'spec_helper'
require 'reel/request/multipart'
require 'net/http'

RSpec.describe Reel::Request::Multipart do

  let(:endpoint) { URI(example_url) }
  let(:response_body) { "ohai thar" }
  let(:txt_filepath){ 'spec/support/multipart_test_example.txt' }
  let(:txt_semicolon_filepath){ 'spec/support/multipart_test_example;.txt' }
  let(:img_path){'logo.png'}

  EOL = "\r\n".freeze
  MULTIPART_BOUNDARY = "Myboundary".freeze
  PART_NAME = "datafile".freeze

  it "return nil if content type is not multipart" do
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

  it "Parses data if content is multipart type" do
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
        expect(req.multipart[PART_NAME][:data]).to eq open(img_path, "rb") {|io| io.read }

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
      post_body << File.read(img_path)
      post_body << "#{EOL}--#{MULTIPART_BOUNDARY}--#{EOL}"

      http = Net::HTTP.new(endpoint.host, endpoint.port)
      request = Net::HTTP::Post.new(endpoint.request_uri)
      request.body = post_body.join
      request["Content-Type"] = "multipart/form-data, boundary=#{MULTIPART_BOUNDARY}"

      http.request(request)

    end

    raise ex if ex
  end

  it "Parses text file data if content is multipart type (missing file name)" do
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
      post_body << "Content-Disposition: form-data; name=\"#{PART_NAME}\"; \"#{EOL}"
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

  it "Parsing error for wrong boundary value" do
      ex = nil

      handler = proc do |connection|
        begin
          req = connection.request
          expect(req.multipart? req.body).to eq true
          expect(req.multipart.empty?).to eq true

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
        request["Content-Type"] = "multipart/form-data, boundary=#{MULTIPART_BOUNDARY}change"

        http.request(request)
      end

      raise ex if ex
    end
    it "Parses data if content is multipart type (filename with semicolons)" do
    ex = nil

    handler = proc do |connection|
      begin
        req = connection.request
        expect(req.multipart? req.body).to eq true
        expect(req.multipart.empty?).to eq false
        expect(req.multipart[PART_NAME][:ended]).to eq true
        expect(req.multipart[PART_NAME][:data]).to eq File.read(txt_semicolon_filepath)

        req.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel(handler) do

      post_body = []
      post_body << "--#{MULTIPART_BOUNDARY}#{EOL}"
      post_body << "Content-Disposition: form-data; name=\"#{PART_NAME}\"; filename=\"#{File.basename(txt_semicolon_filepath)}\"#{EOL}"
      post_body << "Content-Type: text/plain#{EOL}"
      post_body << EOL
      post_body << File.read(txt_semicolon_filepath)
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
