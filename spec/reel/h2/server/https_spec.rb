require File.expand_path '../../spec_helper', __FILE__

RSpec.describe Reel::H2::Server::HTTPS do

  let(:addr) { '127.0.0.1' }
  let(:port) { 1234 }
  let(:url)  { "https://#{addr}:#{port}/" }

  let(:ca_file)              { certs_dir.join('ca.crt').to_s }
  let(:server_cert)          { certs_dir.join("server.crt")         .read }
  let(:server_key)           { certs_dir.join("server.key")         .read }
  let(:client_cert)          { certs_dir.join("client.crt")         .read }
  let(:client_cert_unsigned) { certs_dir.join("client.unsigned.crt").read }
  let(:client_key)           { certs_dir.join("client.key")         .read }
  let(:tls_opts)             { { ca_file: ca_file } }

  before :each do
    @valid = double 'valid'
  end

  def with_tls_server handler = nil, &block
    handler ||= proc do |stream|
      stream.respond :ok
      stream.connection.goaway
    end

    block ||= ->{ H2::Client.get url: url }

    sni = {
      '127.0.0.1' => {
        :cert => server_cert,
        :key  => server_key
      }
    }

    begin
      server = Reel::H2::Server::HTTPS.new host: addr, port: port, sni: sni do |c|
        c.each_stream &handler
      end
      block[server]
    ensure
      server.terminate if server && server.alive?
    end
  end

  it 'accepts TCP connections' do
    with_tls_server do
      s = TCPSocket.new addr, port
      expect(s).to_not be_closed
      s.close
    end
  end

  it 'accepts TLS 1.2 connections' do
    with_tls_server do
      s = TCPSocket.new addr, port
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.alpn_protocols = ['h2']
      ctx.ca_file = ca_file
      ctx.ssl_version = :TLSv1_2
      ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
      s = OpenSSL::SSL::SSLSocket.new s, ctx
      s.sync_close = true
      s.hostname = addr
      s.connect
      expect(s).to_not be_closed
      s.close
    end
  end

  it 'handles HTTP/2 requests & responses' do
    ex = nil
    expect(@valid).to receive(:tap).twice

    handler = proc do |stream|
      begin
        expect(stream.request.headers['hi']).to eq('yo')
        @valid.tap
      rescue RSpec::Expectations::ExpectationNotMetError => ex
      rescue => ex
      ensure
        stream.respond :ok, 'boo'
        stream.connection.goaway
      end
    end

    with_tls_server handler do
      s = H2.get url: url, headers: {'hi' => 'yo'}, tls: tls_opts
      expect(s.body).to eq('boo')
      @valid.tap
    end

    raise ex if ex
  end

end
