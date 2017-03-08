require File.expand_path '../../spec_helper', __FILE__

RSpec.describe Reel::H2::Stream::Response do

  it 'constructs properly with integer status' do
    stream = Object.new
    r = Reel::H2::Stream::Response.new stream: stream,
                                       status: 200
    expect(r.stream).to be(stream)
    expect(r.status).to eq(200)
    expect(r.headers).to be_instance_of(Hash)
    expect(r.headers.length).to eq(1)
    expect(r.headers.keys.first).to eq('content-length')
    expect(r.headers['content-length']).to eq(0)
    expect(r.body).to be_instance_of(String)
    expect(r.body).to be_empty
  end

  it 'constructs properly with symbol status' do
    r = Reel::H2::Stream::Response.new stream: nil, status: :not_found
    expect(r.status).to eq(404)
  end

  it 'constructs properly with string body' do
    r = Reel::H2::Stream::Response.new stream: nil, status: 200, body: 'ohai'
    expect(r.body).to eq('ohai')
    expect(r.headers['content-length']).to eq(4)
  end

  it 'constructs properly with headers' do
    r = Reel::H2::Stream::Response.new stream: nil, status: 301, headers: {location: '/redirected'}
    expect(r.headers[:location]).to eq('/redirected')
  end

  it 'responds on a stream' do
    s = double 'stream'
    expect(s).to receive(:headers).with({
      ':status'        => '200',
      'content-type'   => 'text/plain',
      'content-length' => '4'
    })
    expect(s).to receive(:data).with('ohai')
    r = Reel::H2::Stream::Response.new stream: s,
                                       status: 200,
                                       headers: {content_type: 'text/plain'},
                                       body: 'ohai'
    expect(r.headers['content-length']).to eq(4)
    expect(r.headers[:content_type]).to eq('text/plain')
    expect(r.body).to eq('ohai')
    r.respond_on s
  end

end
