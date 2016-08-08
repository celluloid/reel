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
  MULTIPART_BOUNDARY_WITH_QUOTES = "'t'e\"s\"t".freeze
  PART_NAME = "datafile".freeze

  it "return nil if content type is not multipart" do
    with_socket_pair do |client, peer|

      connection = Reel::Connection.new(peer)

      example_request = ExampleRequest.new

      client << example_request.to_s
      req = connection.request

      expect(req.multipart).to eq nil
      expect(req.multipart?).to eq false

    end
  end

  it "Parses data if content is multipart type" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)

      post_body = ""
      post_body << "--#{MULTIPART_BOUNDARY}#{EOL}"
      post_body << "Content-Disposition: form-data; name=\"#{PART_NAME}\"; filename=\"#{File.basename(txt_filepath)}\"#{EOL}"
      post_body << "Content-Type: text/plain#{EOL}"
      post_body << EOL
      post_body << File.read(txt_filepath)
      post_body << "#{EOL}--#{MULTIPART_BOUNDARY}--#{EOL}"
      example_request = ExampleRequest.new
      example_request.body = post_body
      example_request["Content-Type"] = "multipart/form-data, boundary=#{MULTIPART_BOUNDARY}"

      client << example_request.to_s
      req = connection.request

      expect(req.multipart?).to eq true
      expect(req.multipart.empty?).to eq false
      expect(req.multipart[PART_NAME][:complete]).to eq true
      expect(File.read(req.multipart[PART_NAME][:data])).to eq File.read(txt_filepath)
    end
  end

  it "Parses data from image uploaded" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)

      post_body = ""
      post_body << "--#{MULTIPART_BOUNDARY}#{EOL}"
      post_body << "Content-Disposition: form-data; name=\"#{PART_NAME}\"; filename=\"#{File.basename(img_path)}\"#{EOL}"
      post_body << "Content-Type: application/octet-stream#{EOL}"
      post_body << EOL
      post_body << IO.binread(img_path)
      post_body << "#{EOL}--#{MULTIPART_BOUNDARY}--#{EOL}"
      example_request = ExampleRequest.new
      example_request.body = post_body
      example_request["Content-Type"] = "multipart/form-data, boundary=#{MULTIPART_BOUNDARY}"

      client << example_request.to_s
      req = connection.request

      expect(req.multipart?).to eq true
      expect(req.multipart.empty?).to eq false
      expect(req.multipart[PART_NAME][:complete]).to eq true
      expect(IO.binread(req.multipart[PART_NAME][:data])).to eq IO.binread(img_path)
    end
  end

  it "Parses text file data if content is multipart type (missing file name)" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)

      post_body = ""
      post_body << "--#{MULTIPART_BOUNDARY}#{EOL}"
      post_body << "Content-Disposition: form-data; name=\"#{PART_NAME}\"; \"#{EOL}"
      post_body << "Content-Type: text/plain#{EOL}"
      post_body << EOL
      post_body << File.read(txt_filepath)
      post_body << "#{EOL}--#{MULTIPART_BOUNDARY}--#{EOL}"
      example_request = ExampleRequest.new
      example_request.body = post_body
      example_request["Content-Type"] = "multipart/form-data, boundary=#{MULTIPART_BOUNDARY}"

      client << example_request.to_s
      req = connection.request

      expect(req.multipart?).to eq true
      expect(req.multipart.empty?).to eq false
      expect(req.multipart[PART_NAME][:complete]).to eq true
      expect(File.read(req.multipart[PART_NAME][:data])).to eq File.read(txt_filepath)
    end
  end

  it "Parsing error for wrong boundary value" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)

      post_body = ""
      post_body << "--#{MULTIPART_BOUNDARY}#{EOL}"
      post_body << "Content-Disposition: form-data; name=\"#{PART_NAME}\"; filename=\"#{File.basename(txt_filepath)}\"#{EOL}"
      post_body << "Content-Type: text/plain#{EOL}"
      post_body << EOL
      post_body << File.read(txt_filepath)
      post_body << "#{EOL}--#{MULTIPART_BOUNDARY}--#{EOL}"
      example_request = ExampleRequest.new
      example_request.body = post_body
      example_request["Content-Type"] = "multipart/form-data, boundary=#{MULTIPART_BOUNDARY}change"

      client << example_request.to_s
      req = connection.request

      expect(req.multipart?).to eq true
      expect(req.multipart.empty?).to eq true
    end
  end

  it "Parses data if content is multipart type (filename with semicolons)" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)

        post_body = ""
        post_body << "--#{MULTIPART_BOUNDARY}#{EOL}"
        post_body << "Content-Disposition: form-data; name=\"#{PART_NAME}\"; filename=\"temp;.txt\"#{EOL}"
        post_body << "Content-Type: text/plain#{EOL}"
        post_body << EOL
        post_body << "temp"
        post_body << "#{EOL}--#{MULTIPART_BOUNDARY}--#{EOL}"
        example_request = ExampleRequest.new
        example_request.body = post_body
        example_request["Content-Type"] = "multipart/form-data, boundary=#{MULTIPART_BOUNDARY}"

        client << example_request.to_s
        req = connection.request

        expect(req.multipart?).to eq true
        expect(req.multipart.empty?).to eq false
        expect(req.multipart[PART_NAME][:complete]).to eq true
        expect(File.read(req.multipart[PART_NAME][:data])).to eq "temp"
      end
  end

  it "Parses data if content is multipart type (Boundary with quotes)" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)

      post_body = ""
      post_body << "--#{MULTIPART_BOUNDARY_WITH_QUOTES}#{EOL}"
      post_body << "Content-Disposition: form-data; name=\"#{PART_NAME}\"; filename=\"#{File.basename(txt_filepath)}\"#{EOL}"
      post_body << "Content-Type: text/plain#{EOL}"
      post_body << EOL
      post_body << File.read(txt_filepath)
      post_body << "#{EOL}--#{MULTIPART_BOUNDARY_WITH_QUOTES}--#{EOL}"
      example_request = ExampleRequest.new
      example_request.body = post_body
      example_request["Content-Type"] = "multipart/form-data, boundary=#{MULTIPART_BOUNDARY_WITH_QUOTES}"

      client << example_request.to_s
      req = connection.request

      expect(req.multipart?).to eq true
      expect(req.multipart.empty?).to eq false
      expect(req.multipart[PART_NAME][:complete]).to eq true
      expect(File.read(req.multipart[PART_NAME][:data])).to eq File.read(txt_filepath)
    end
  end
end
