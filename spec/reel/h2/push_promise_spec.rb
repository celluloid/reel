require File.expand_path '../spec_helper', __FILE__
require 'colored'

# Reel::Logger.logger.level = ::Logger::DEBUG
# Reel::H2.verbose!

RSpec.describe Reel::H2::Stream do

  let(:addr) { '127.0.0.1' }
  let(:port) { 1234 }
  let(:url)  { "http://#{addr}:#{port}/" }

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

  describe :push_promise do

    it 'sends HTTP/2 push promises' do
      expect(@valid).to receive(:tap).twice

      handler = proc do |stream|
        stream.on_complete do
          stream.connection.goaway
          @valid.tap
        end
        stream.push_promise '/push', 'promise'
        stream.respond :ok
      end

      with_server handler do
        s = ::H2.get url: url, tls: false
        s.client.block!
        expect(s.pushes.length).to eq(1)
        p = s.pushes.first
        expect(p.headers[':path']).to eq('/push')
        expect(p.body).to eq('promise')
        @valid.tap
      end
    end

  end

  describe :push_promise_for do

    it 'sends HTTP/2 push promises' do
      expect(@valid).to receive(:tap).twice

      handler = proc do |stream|
        stream.on_complete do
          stream.connection.goaway
          @valid.tap
        end
        pp = stream.push_promise_for '/push', 'promise'
        pp.make_on stream
        stream.respond :ok
        pp.keep_async
      end

      with_server handler do
        s = ::H2.get url: url, tls: false
        s.client.block!
        expect(s.pushes.length).to eq(1)
        p = s.pushes.first
        expect(p.headers[':path']).to eq('/push')
        expect(p.body).to eq('promise')
        @valid.tap
      end
    end

  end

  it 'cancels HTTP/2 push promises on stream reset' do
    ex = nil
    expect(@valid).to receive(:tap).twice

    handler = proc do |stream|
      begin
        stream.on_complete do
          stream.connection.goaway
          @valid.tap
        end
        pp = stream.push_promise_for '/push', {'etag' => '1234'}, 'promise'
        pp.make_on stream
        stream.respond :ok
        Celluloid.sleep 1 # wait for client to cancel
        expect(pp.keep).to be false
        expect(pp).to be_canceled
      rescue RSpec::Expectations::ExpectationNotMetError => ex
      rescue => ex
      end
    end

    with_server handler do
      c = ::H2::Client.new url: url, tls: false do |client|
        client.on :promise do |p|
          p.on :headers do |h|
            if h['etag'] == '1234'
              p.cancel!
              @valid.tap
            end
          end
        end
      end
      s = c.get path: '/'
      c.block!
    end

    raise ex if ex
  end

end
