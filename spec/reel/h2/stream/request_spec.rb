require File.expand_path '../../spec_helper', __FILE__

RSpec.describe Reel::H2::Stream::Request do

  let :stream do
    s = double 'stream'
    Reel::H2::Stream::STREAM_EVENTS.each do |se|
      expect(s).to receive(:on).with(se).once
    end
    Reel::H2::Stream::STREAM_DATA_EVENTS.each do |se|
      expect(s).to receive(:on).with(se).once
    end
    s
  end

  it 'constructs, responds properly' do
    s = double 'stream'
    expect(s).to receive(:connection)
    expect(s).to receive(:respond).with(:ok, 1, 2)
    r = Reel::H2::Stream::Request.new s
    expect(r.stream).to be(s)
    expect(r.headers).to be_instance_of(Hash)
    expect(r.headers).to be_empty
    expect(r.body).to be_instance_of(String)
    expect(r.body).to be_empty
    expect(r.addr).to be_nil
    expect(r.method).to be_nil
    expect(r.path).to be_nil
    r.respond :ok, 1, 2
  end

  it 'accesses header keys' do
    s = Reel::H2::Stream.new connection: nil, stream: stream
    s.__send__ :on_active
    s.__send__ :on_headers, {
      'Content-Type' => 'application/vnd.example.com-v2+json',
      'Authorization' => 'Bearer token',
      'test_key' => 'test_value'
    }
    r = s.request
    expect(r.headers[:content_type]).to eq('application/vnd.example.com-v2+json')
    expect(r.headers['AUTHORIZATION']).to eq('Bearer token')
    expect(r.headers['test_key']).to eq('test_value')
  end

  it 'returns peer socket IP address' do
    s = double 'stream'
    expect(s).to receive(:connection).and_return(s)
    expect(s).to receive(:socket).and_return(s)
    expect(s).to receive(:peeraddr).and_return(s)
    expect(s).to receive(:[]).with(3).and_return('ohai')

    r = Reel::H2::Stream::Request.new s
    expect(r.addr).to eq('ohai')
  end

  it 'returns request method symbol' do
    s = double 'stream'
    r = Reel::H2::Stream::Request.new s
    r.headers.merge! ':method' => 'GET'
    expect(r.method).to be(:get)
  end

  it 'returns request path' do
    s = double 'stream'
    r = Reel::H2::Stream::Request.new s
    r.headers.merge! ':method' => 'GET'
    expect(r.method).to be(:get)
  end

end
