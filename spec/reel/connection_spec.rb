require 'spec_helper'

describe Reel::Connection do
  let(:fixture_path) { File.expand_path("../../fixtures/example.txt", __FILE__) }

  it "reads requests without bodies" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
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
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      body = "Hello, world!"
      example_request = ExampleRequest.new
      example_request.body = body

      client << example_request.to_s
      request = connection.request

      request.url.should     eq "/"
      request.version.should eq "1.1"
      request['Content-Length'].should eq body.length.to_s
      request.body.to_s.should eq example_request.body
    end
  end

  it "reads requests with large bodies" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
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

  it "enumerates requests with #each_request" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      client << ExampleRequest.new.to_s

      request_count = 0
      connection.each_request do |request|
        request_count += 1
        request.url.should eq "/"
        request.respond :ok
        client.close
      end

      request_count.should eq 1
    end
  end

  context "streams responses when transfer-encoding is chunked" do
    def test_chunked_response(request, client)
      # Sending transfer_encoding chunked without a body enables streaming mode
      request.respond :ok, :transfer_encoding => :chunked

      # This will send individual chunks
      request << "Hello"
      request << "World"
      request.finish_response # Write trailer and reset connection to header mode

      response = ""

      begin
        while chunk = client.readpartial(4096)
          response << chunk
          break if response =~ /0\r\n\r\n$/
        end
      rescue EOFError
      end

      crlf = "\r\n"
      fixture = "5#{crlf}Hello#{crlf}5#{crlf}World#{crlf}0#{crlf*2}"
      response[(response.length - fixture.length)..-1].should eq fixture
    end
    
    it "with keep-alive" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)
        client << ExampleRequest.new.to_s
        request = connection.request

        test_chunked_response(request, client)
        connection.close
      end
    end

    it "without keep-alive" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)
        client << ExampleRequest.new.tap{ |r|
          r['Connection'] = 'close'
        }.to_s
        request = connection.request

        test_chunked_response(request, client)
        connection.close
      end
    end

    it "with pipelined requests" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)

        2.times do
          client << ExampleRequest.new.to_s
        end
        client << ExampleRequest.new.tap { |r|
          r['Connection'] = 'close'
        }.to_s

        3.times do
          request = connection.request
          test_chunked_response(request, client)
        end
        connection.close
      end
    end
  end
  
  it "reset the request after a response is sent" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      example_request = ExampleRequest.new(:get, "/", "1.1", {'Connection' => 'close'})
      client << example_request

      connection.request.should_not be_false

      connection.respond :ok, "Response sent"

      connection.request.should be_false
    end
  end

  it "raises an error trying to read two pipelines without responding first" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)

      2.times do
        client << ExampleRequest.new.to_s
      end

      expect do
        2.times { request = connection.request }
      end.to raise_error(Reel::StateError)
    end
  end

  it "reads pipelined requests without bodies" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)

      3.times { client << ExampleRequest.new.to_s }

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
        connection.respond :ok, {}, ""
      end
    end
  end

  it "reads pipelined requests with bodies" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)

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
        request.body.to_s.should eq expected_body

        connection.respond :ok, {}, ""
      end
    end
  end

  it "reads pipelined requests with streamed bodies" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer, 4)

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
        request.should_not be_finished_reading
        new_content = ""
        while chunk = request.body.readpartial(1)
          new_content << chunk
        end
        new_content.should == expected_body
        request.should be_finished_reading

        connection.respond :ok, {}, ""
      end
    end
  end

  # This test will deadlock rspec waiting unless
  # connection.request works properly
  it "does not block waiting for body to read before handling request" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      example_request = ExampleRequest.new

      content = "Hi guys! Sorry I'm late to the party."
      example_request['Content-Length'] = content.length
      client << example_request.to_s

      request = connection.request
      request.should be_a(Reel::Request)
      client << content
      request.body.to_s.should == content
    end
  end

  it "blocks on read until written" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      example_request = ExampleRequest.new

      content = "Hi guys! Sorry I'm late to the party."
      example_request['Content-Length'] = content.length
      client << example_request.to_s

      request = connection.request
      timers = Timers.new
      timers.after(0.2){
        client << content
      }
      read_body = ""
      timers.after(0.1){
        timers.wait # continue timers, the next bit will block waiting for content
        read_body = request.read(8)
      }
      timers.wait

      request.should be_a(Reel::Request)
      read_body.should == content[0..7]
    end
  end

  it "streams body properly with #read and buffered body" do
    with_socket_pair do |client, peer|
      connection = Reel::Connection.new(peer)
      example_request = ExampleRequest.new

      content = "I'm data you can stream!"
      example_request['Content-Length'] = content.length
      client << example_request.to_s

      request = connection.request
      request.should be_a(Reel::Request)
      request.should_not be_finished_reading
      client << content
      rebuilt = []
      connection.readpartial(64) # Buffer some body
      while chunk = request.read(8)
        rebuilt << chunk
      end
      request.should be_finished_reading
      rebuilt.should == ["I'm data", " you can", " stream!"]
    end
  end

  context "#readpartial" do
    it "streams request bodies" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer, 8)
        example_request = ExampleRequest.new

        content = "I'm data you can stream!"
        example_request['Content-Length'] = content.length
        client << example_request.to_s

        request = connection.request
        request.should be_a(Reel::Request)
        request.should_not be_finished_reading
        client << content
        rebuilt = []
        while chunk = request.body.readpartial(8)
          rebuilt << chunk
        end
        request.should be_finished_reading
        rebuilt.should == ["I'm data", " you can", " stream!"]
      end
    end
  end

  context "#each" do
    it "streams request bodies" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)
        example_request = ExampleRequest.new

        content = "I'm data you can stream!"
        example_request['Content-Length'] = content.length
        client << example_request.to_s

        request = connection.request
        request.should be_a(Reel::Request)
        request.should_not be_finished_reading
        client << content

        data = ""
        request.body.each { |chunk| data << chunk }
        request.should be_finished_reading
        data.should == "I'm data you can stream!"
      end
    end
  end

  describe "IO#read duck typing" do
    it "raises an exception if length is a negative value" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)
        example_request = ExampleRequest.new

        client << example_request.to_s
        request = connection.request

        lambda { request.read(-1) }.should raise_error(ArgumentError)
      end
    end

    it "returns an empty string if the length is zero" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)
        example_request = ExampleRequest.new

        client << example_request.to_s
        request = connection.request

        request.read(0).should be_empty
      end
    end

    it "reads to EOF if length is nil, even small buffer" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer, 4)
        example_request = ExampleRequest.new
        example_request.body = "Hello, world!"
        connection.buffer_size.should == 4

        client << example_request.to_s
        request = connection.request

        request.read.should eq "Hello, world!"
      end
    end

    it "reads to EOF if length is nil" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)
        example_request = ExampleRequest.new
        example_request.body = "Hello, world!"


        client << example_request.to_s
        request = connection.request

        request.read.should eq "Hello, world!"
      end
    end

    it "uses the optional buffer to recieve data" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)
        example_request = ExampleRequest.new
        example_request.body = "Hello, world!"

        client << example_request.to_s
        request = connection.request

        buffer = ''
        request.read(nil, buffer).should eq "Hello, world!"
        buffer.should eq "Hello, world!"
      end
    end

    it "returns with the content it could read when the length longer than EOF" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)
        example_request = ExampleRequest.new
        example_request.body = "Hello, world!"

        client << example_request.to_s
        request = connection.request

        request.read(1024).should eq "Hello, world!"
      end
    end

    it "returns nil at EOF if a length is passed" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)
        example_request = ExampleRequest.new

        client << example_request.to_s
        request = connection.request

        request.read(1024).should be_nil
      end
    end

    it "returns an empty string at EOF if length is nil" do
      with_socket_pair do |client, peer|
        connection = Reel::Connection.new(peer)
        example_request = ExampleRequest.new

        client << example_request.to_s
        request = connection.request

        request.read.should be_empty
      end
    end
  end
end
