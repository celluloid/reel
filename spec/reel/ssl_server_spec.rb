require 'spec_helper'
require 'net/http'

describe Reel::SSLServer do
  let(:example_ssl_port) { example_port + 1 }
  let(:example_url)      { "https://#{example_addr}:#{example_ssl_port}#{example_path}" }
  let(:endpoint)         { URI(example_url) }
  let(:response_body)    { "ohai thar" }

  let(:server_cert) { fixture_dir.join("server.crt").read }
  let(:server_key)  { fixture_dir.join("server.key").read }

  it "receives HTTP requests and sends responses" do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        request.method.should eq 'GET'
        request.version.should eq "1.1"
        request.url.should eq example_path

        connection.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel_sslserver(handler) do
      http = Net::HTTP.new(endpoint.host, endpoint.port)
      http.use_ssl = true

      # FIXME: VERIFY_NONE is bad! Authenticate the server cert!
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Get.new(endpoint.path)
      response = http.request(request)

      response.body.should eq response_body
    end

    raise ex if ex
  end

  def with_reel_sslserver(handler, context = OpenSSL::SSL::SSLContext.new)
    options = {
      :cert => server_cert,
      :key  => server_key
    }

    server = Reel::SSLServer.new(example_addr, example_ssl_port, options, &handler)
    yield server
  ensure
    server.terminate if server && server.alive?
  end
end
