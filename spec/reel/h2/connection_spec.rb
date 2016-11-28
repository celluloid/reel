require File.expand_path '../spec_helper', __FILE__

RSpec.describe Reel::H2::Connection do

  let :parser do
    p = double 'parser'
    Reel::H2::Connection::PARSER_EVENTS.each do |pe|
      expect(p).to receive(:on).with(pe).once
    end
    p
  end

  it 'constructs properly' do
    with_socket_pair do |client, peer|
      server = Object.new
      c = Reel::H2::Connection.new socket: peer, server: server
      expect(c).to be_attached
      expect(c).to_not be_closed
      expect(c.each_stream).to be_nil
      expect(c.parser).to be_instance_of(HTTP2::Server)
      expect(c.server).to be(server)
      expect(c.socket).to be(peer)
    end
  end

  it 'detaches properly' do
    with_socket_pair do |client, peer|
      c = Reel::H2::Connection.new socket: peer, server: nil
      expect(c.detach).to be(c)
      expect(c).to_not be_attached
      expect(->{ c.read }).to_not raise_error
      expect(c).to_not be_closed
      expect(->{ c.close }).to_not raise_error
      expect(c).to_not be_closed
    end
  end

  it 'binds events to the parser' do
    c = Reel::H2::Connection.new socket: nil, server: nil do |c|
      c.instance_variable_set :@parser, parser
    end
  end

  it 'reads data from the socket into the parser' do
    p = parser
    expect(p).to receive(:<<).with(kind_of(String)).exactly(10).times

    with_socket_pair do |client, peer|
      c = Reel::H2::Connection.new socket: peer, server: nil do |c|
        c.instance_variable_set :@parser, p
      end
      reader = Thread.new { c.read }
      5.times { client.write 'a'*8192}
      client.close
      reader.join
    end
  end

  it 'constructs a new Stream on :stream event' do
    stream = double 'stream'

    Reel::H2::Stream::STREAM_EVENTS.each do |se|
      expect(stream).to receive(:on).with(se).once
    end

    Reel::H2::Stream::STREAM_DATA_EVENTS.each do |se|
      expect(stream).to receive(:on).with(se).once
    end

    c = Reel::H2::Connection.new socket: nil, server: nil
    c.__send__ :on_stream, stream
  end

end
