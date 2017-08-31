require File.expand_path '../../spec_helper', __FILE__

RSpec.describe Reel::H2::Server::HTTP do

  let(:addr) { '127.0.0.1' }
  let(:port) { 1234 }
  let(:url)  { "http://#{addr}:#{port}/" }

  let :streams do
    ENV['STREAMS'] ? Integer(ENV['STREAMS']) : 5
  end

  let :connections do
    ENV['CONNECTIONS'] ? Integer(ENV['CONNECTIONS']) : 32
  end

  def with_server handler = nil, &block
    handler ||= proc do |stream|
      stream.respond :ok
      stream.connection.goaway
    end

    block ||= ->{ H2.get url: url, tls: false }

    begin
      server = Reel::H2::Server::HTTP.new host: addr, port: port, spy: false do |c|
        c.each_stream &handler
      end
      block[server]
    ensure
      server.terminate if server && server.alive?
    end
  end

  before :each do
    @valid = double 'valid'
  end

  it 'accepts TCP connections' do
    with_server do
      s = TCPSocket.new addr, port
      expect(s).to_not be_closed
      s.close
    end
  end

  it 'reads HTTP/2 requests' do
    ex = nil
    expect(@valid).to receive(:tap).twice

    handler = proc do |stream|
      begin
        expect(stream).to be_instance_of(Reel::H2::Stream)
        r = stream.request
        expect(r).to be_instance_of(Reel::H2::Stream::Request)
        expect(r.method).to be :post
        expect(r.headers['test-header']).to eq('test_value')
        expect(r.body).to eq('test_body')
        @valid.tap
      rescue RSpec::Expectations::ExpectationNotMetError => ex
      rescue => ex
      ensure
        stream.respond :ok
        stream.connection.goaway
      end
    end

    with_server handler do
      ::H2.post(url: url,
                headers: {'test-header' => 'test_value'},
                body: 'test_body',
                tls: false).block!
      @valid.tap
    end

    raise ex if ex
  end

  it 'sends HTTP/2 responses' do
    expect(@valid).to receive(:tap).twice

    handler = proc do |stream|
      stream.respond :ok, {'test-header' => 'test_value'}, 'test_body'
      stream.connection.goaway
      @valid.tap
    end

    with_server handler do
      s = H2.get url: url, tls: false
      s.block!
      expect(s).to be_closed
      expect(s.headers[':status']).to eq('200')
      expect(s.headers['content-length']).to eq('test_body'.bytesize.to_s)
      expect(s.headers['test-header']).to eq('test_value')
      expect(s.body).to eq('test_body')
      @valid.tap
    end
  end

  it 'handles many HTTP/2 connections' do
    expect(@valid).to receive(:tap).exactly(connections * 2).times

    handler = proc do |stream|
      stream.respond :ok
      stream.connection.goaway
      @valid.tap
    end

    mutex = Mutex.new

    with_server handler do
      clients = Array.new(connections).map do
        mutex.synchronize do
          c = H2::Client.new addr: addr, port: port, tls: false
          c.get path: '/'
          c
        end
      end

      clients.each do |c|
        mutex.synchronize do
          c.block!
          expect(c.last_stream).to be_ok
          expect(c).to be_closed
          @valid.tap
        end
      end
    end
  end

  it 'handles many HTTP/2 streams' do
    count = streams
    expect(@valid).to receive(:tap).exactly(streams).times

    handler = proc do |stream|
      count -= 1
      stream.respond :ok
      stream.connection.goaway if count == 0
      @valid.tap
    end

    with_server handler do
      c = H2::Client.new addr: addr, port: port, tls: false
      streams.times { c.get path: '/' }
      c.block!
      expect(count).to eq 0
      expect(c).to be_closed
    end
  end

  it 'handles many HTTP/2 streams on many connections' do
    count = Hash.new {|h,k| h[k] = streams}
    expect(@valid).to receive(:tap).exactly(connections * streams).times

    handler = proc do |stream|
      conn = stream.connection
      count[conn] -= 1
      stream.respond :ok
      @valid.tap
      conn.goaway if count[conn] == 0
    end

    with_server handler do
      clients = Array.new(connections).map { H2::Client.new addr: addr, port: port, tls: false }
      clients.each {|c| streams.times { c.get path: '/' }}
      clients.each &:block!
      count.each {|_,v| expect(v).to eq 0}
      clients.each {|c| expect(c).to be_closed}
    end
  end

end
