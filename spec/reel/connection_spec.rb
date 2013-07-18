require 'spec_helper'

describe Reel::Connection do
  let(:fixture_path) { File.expand_path("../../fixtures/example.txt", __FILE__) }

  it "reads requests without bodies" do
    with_socket_pair do |client, connection|
      client << ExampleRequest.new.to_s
      request = connection.request

      request.url.should     eq "/"
      request.version.should eq "1.1"

      request['Host'].should eq "www.example.com"
      request['Connection'].should eq "keep-alive"
      request['User-Agent'].should eq "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.78 S"
      request['Accept'].should eq "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      request['Accept-Encoding'].should eq "gzip,deflate,sdch"
      request['Accept-Language'].should eq "en-US,en;q=0.8"
      request['Accept-Charset'].should eq "ISO-8859-1,utf-8;q=0.7,*;q=0.3"
    end
  end

  it "reads requests with bodies" do
    with_socket_pair do |client, connection|
      body = "Hello, world!"
      example_request = ExampleRequest.new
      example_request.body = body

      client << example_request.to_s
      request = connection.request

      request.url.should     eq "/"
      request.version.should eq "1.1"
      request['Content-Length'].should eq body.length.to_s
      request.body.should eq example_request.body
    end
  end

  it "serves static files" do
    with_socket_pair do |client, connection|
      client << ExampleRequest.new.to_s
      request = connection.request

      fixture_text = File.read(fixture_path)
      File.open(fixture_path) do |file|
        connection.respond :ok, file
        connection.close
      end

      response = client.read(4096)
      response[(response.length - fixture_text.length)..-1].should eq fixture_text
    end
  end

  it "streams responses when transfer-encoding is chunked" do
    with_socket_pair do |client, connection|
      client << ExampleRequest.new.to_s
      request = connection.request

      # Sending transfer_encoding chunked without a body enables streaming mode
      connection.respond :ok, :transfer_encoding => :chunked

      # This will send individual chunks
      connection << "Hello"
      connection << "World"
      connection.finish_response # Write trailer and reset connection to header mode
      connection.close

      response = ""

      begin
        while chunk = client.readpartial(4096)
          response << chunk
        end
      rescue EOFError
      end

      crlf = "\r\n"
      fixture = "5#{crlf}Hello#{crlf}5#{crlf}World#{crlf}0#{crlf*2}"
      response[(response.length - fixture.length)..-1].should eq fixture
    end
  end

  it "reset the request after a response is sent" do
    with_socket_pair do |client, connection|
      example_request = ExampleRequest.new(:get, "/", "1.1", {'Connection' => 'close'})
      client << example_request

      connection.request.should_not be_false

      connection.respond :ok, "Response sent"

      connection.request.should be_false
    end
  end

  it "reads pipelined requests without bodies" do
    with_socket_pair do |client, connection|
      3.times do
        client << ExampleRequest.new.to_s
      end

      3.times do
        request = connection.request

        request.url.should     eq "/"
        request.version.should eq "1.1"

        request['Host'].should eq "www.example.com"
        request['Connection'].should eq "keep-alive"
        request['User-Agent'].should eq "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.78 S"
        request['Accept'].should eq "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        request['Accept-Encoding'].should eq "gzip,deflate,sdch"
        request['Accept-Language'].should eq "en-US,en;q=0.8"
        request['Accept-Charset'].should eq "ISO-8859-1,utf-8;q=0.7,*;q=0.3"
      end
    end
  end

  it "reads pipelined requests with bodies" do
    with_socket_pair do |client, connection|
      3.times do |i|
        body = "Hello, world number #{i}!"
        example_request = ExampleRequest.new
        example_request.body = body

        client << example_request.to_s
      end

      3.times do |i|
        request = connection.request

        expected_body = "Hello, world number #{i}!"
        request.url.should     eq "/"
        request.version.should eq "1.1"
        request['Content-Length'].should eq expected_body.length.to_s
        request.body.should eq expected_body
      end
    end
  end
  describe "Connection#read behaving like IO#read" do
    it "raises an exception if length is a negative value" do
      with_socket_pair do |client, connection|
        example_request = ExampleRequest.new

        client << example_request.to_s
        request = connection.request

        lambda { request.read(-1) }.should raise_error(ArgumentError)
      end
    end

    it "returns an empty string if the length is zero" do
      with_socket_pair do |client, connection|
        example_request = ExampleRequest.new

        client << example_request.to_s
        request = connection.request

        request.read(0).should be_empty
      end
    end

    it "reads to EOF if length is nil" do
      with_socket_pair do |client, connection|
        body = "Hello, world!"
        example_request = ExampleRequest.new
        example_request.body = body

        client << example_request.to_s
        request = connection.request

        request.read.should eq "Hello, world!"
      end
    end

    it "uses the optional buffer to recieve data" do
      with_socket_pair do |client, connection|
        body = "Hello, world!"
        example_request = ExampleRequest.new
        example_request.body = body

        client << example_request.to_s
        request = connection.request

        buffer = ''
        request.read(nil, buffer).should eq "Hello, world!"
        buffer.should eq "Hello, world!"
      end
    end

    it "returns with the content it could read when the length longer than EOF" do
      with_socket_pair do |client, connection|
        body = "Hello, world!"
        example_request = ExampleRequest.new
        example_request.body = body

        client << example_request.to_s
        request = connection.request

        request.read(1024).should eq "Hello, world!"
      end
    end

    it "returns nil at EOF if a length is passed" do
      with_socket_pair do |client, connection|
        example_request = ExampleRequest.new

        client << example_request.to_s
        request = connection.request

        request.read(1024).should be_nil
      end
    end

    it "returns an empty string at EOF if length is nil" do
      with_socket_pair do |client, connection|
        example_request = ExampleRequest.new

        client << example_request.to_s
        request = connection.request

        request.read.should be_empty
      end
    end

  end

end
