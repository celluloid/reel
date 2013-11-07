require 'spec_helper'
require 'net/http'

describe Reel::SSLServer do
  let(:example_ssl_port) { example_port + 1 }
  let(:example_url)      { "https://#{example_addr}:#{example_ssl_port}#{example_path}" }
  let(:endpoint)         { URI(example_url) }
  let(:response_body)    { "ohai thar" }

  let(:ca_file) { fixture_dir.join('ca.crt').to_s }

  let(:server_cert) { fixture_dir.join("server.crt").read }
  let(:server_key)  { fixture_dir.join("server.key").read }
  let(:client_cert) { fixture_dir.join("client.crt").read }
  let(:client_key)  { fixture_dir.join("client.key").read }

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
      http         = Net::HTTP.new(endpoint.host, endpoint.port)
      http.use_ssl = true
      http.ca_file = self.ca_file

      request = Net::HTTP::Get.new(endpoint.path)
      response = http.request(request)

      response.body.should eq response_body
    end

    raise ex if ex
  end

  it 'verifies client SSL certs when provided with a CA' do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        request.method.should eq 'GET'
        request.version.should eq '1.1'
        request.url.should eq example_path

        connection.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel_sslserver(handler, :ca_file => self.ca_file) do
      http         = Net::HTTP.new(endpoint.host, endpoint.port)
      http.use_ssl = true
      http.ca_file = self.ca_file
      http.cert    = OpenSSL::X509::Certificate.new self.client_cert
      http.key     = OpenSSL::PKey::RSA.new         self.client_key

      request  = Net::HTTP::Get.new(endpoint.path)
      response = http.request(request)

      response.body.should eq response_body
    end

    raise ex if ex
  end

  def with_reel_sslserver(handler, options = {})
    options = {
      :cert => server_cert,
      :key  => server_key
    }.merge(options)

    server = Reel::SSLServer.new(example_addr, example_ssl_port, options, &handler)
    yield server
  ensure
    server.terminate if server && server.alive?
  end
end
