require 'spec_helper'
require 'net/http'

RSpec.describe Reel::Server::HTTPS do
  let(:example_https_port) { example_port + 1 }
  let(:example_url)      { "https://#{example_addr}:#{example_https_port}#{example_path}" }
  let(:endpoint)         { URI(example_url) }
  let(:response_body)    { "ohai thar" }

  let(:ca_file)              { certs_dir.join('ca.crt').to_s }

  let(:server_cert)          { certs_dir.join("server.crt")         .read }
  let(:server_key)           { certs_dir.join("server.key")         .read }
  let(:client_cert)          { certs_dir.join("client.crt")         .read }
  let(:client_cert_unsigned) { certs_dir.join("client.unsigned.crt").read }
  let(:client_key)           { certs_dir.join("client.key")         .read }

  it "receives HTTP requests and sends responses" do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        expect(request.method).to eq 'GET'
        expect(request.version).to eq "1.1"
        expect(request.url).to eq example_path

        connection.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel_https_server(handler) do
      http         = Net::HTTP.new(endpoint.host, endpoint.port)
      http.use_ssl = true
      http.ca_file = self.ca_file

      request = Net::HTTP::Get.new(endpoint.path)
      response = http.request(request)

      expect(response.body).to eq response_body
    end

    raise ex if ex
  end

  it 'verifies client SSL certs when provided with a CA' do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        expect(request.method).to eq 'GET'
        expect(request.version).to eq '1.1'
        expect(request.url).to eq example_path

        connection.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel_https_server(handler, :ca_file => self.ca_file) do
      http         = Net::HTTP.new(endpoint.host, endpoint.port)
      http.use_ssl = true
      http.ca_file = self.ca_file
      http.cert    = OpenSSL::X509::Certificate.new self.client_cert
      http.key     = OpenSSL::PKey::RSA.new         self.client_key

      request  = Net::HTTP::Get.new(endpoint.path)
      response = http.request(request)

      expect(response.body).to eq response_body
    end

    raise ex if ex
  end

  it %{fails to verify client certificates that aren't signed} do
    ex = nil

    handler = proc do |connection|
      begin
        request = connection.request
        expect(request.method).to eq 'GET'
        expect(request.version).to eq '1.1'
        expect(request.url).to eq example_path

        connection.respond :ok, response_body
      rescue => ex
      end
    end

    with_reel_https_server(handler, :ca_file => self.ca_file) do
      http         = Net::HTTP.new(endpoint.host, endpoint.port)
      http.use_ssl = true
      http.ca_file = self.ca_file
      http.cert    = OpenSSL::X509::Certificate.new self.client_cert_unsigned
      http.key     = OpenSSL::PKey::RSA.new         self.client_key

      request  = Net::HTTP::Get.new(endpoint.path)

      expect { http.request(request) }.to raise_error(OpenSSL::SSL::SSLError)
    end

    raise ex if ex
  end

  def with_reel_https_server(handler, options = {})
    options = {
      :cert => server_cert,
      :key  => server_key
    }.merge(options)

    server = described_class.new(example_addr, example_https_port, options, &handler)
    yield server
  ensure
    server.terminate if server && server.alive?
  end
end
