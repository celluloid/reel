require 'spec_helper'

describe Reel::Connection do
  it "reads requests" do
    host = '127.0.0.1'
    port = 10103

    server = TCPServer.new(host, port)
    client = TCPSocket.new(host, port)
    socket = Reel::Connection.new(server.accept)

    header_path = File.expand_path('../../fixtures/chrome.txt', __FILE__)
    client << File.read(header_path)
    request = socket.read_request

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
