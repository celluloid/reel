require 'spec_helper'

describe Reel::Response::Writer do
  let(:fixture_path) { File.expand_path("../../fixtures/example.txt", __FILE__) }
  let(:expected_response) { "HTTP/1.1 200 OK\r\nContent-Length: 56\r\n\r\n#{File.read(fixture_path)}" }
  it "streams static files" do
    with_socket_pair do |socket, peer|
      writer = described_class.new(socket)

      File.open(fixture_path, 'r') do |file|
        response = Reel::Response.new(:ok, {}, file)
        writer.handle_response(response)
      end

      peer.readpartial(4096).should eq expected_response
    end
  end
end
