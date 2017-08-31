require File.expand_path '../spec_helper', __FILE__

RSpec.describe Reel::H2::Stream do

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

  it 'constructs properly, binding stream events' do
    c = Object.new
    s = stream
    str = Reel::H2::Stream.new connection: c, stream: s
    expect(str.connection).to be(c)
    expect(str.push_promises).to be_instance_of(Set)
    expect(str.push_promises).to be_empty
    expect(str.stream).to be(s)
  end

  it 'creates a new Request object on active' do
    s = stream
    str = Reel::H2::Stream.new connection: nil, stream: s
    expect(str.request).to be_nil
    str.__send__ :on_active
    expect(str.request).to be_instance_of(Reel::H2::Stream::Request)
  end

  it 'merges incoming headers into the Request object' do
    s = stream
    str = Reel::H2::Stream.new connection: nil, stream: s
    str.__send__ :on_active
    expect(str.request).to be_instance_of(Reel::H2::Stream::Request)
    str.__send__ :on_headers, {foo: 'bar'}
    expect(str.request.headers[:foo]).to eq('bar')
  end

  it 'appends data to the Request object' do
    s = stream
    str = Reel::H2::Stream.new connection: nil, stream: s
    str.__send__ :on_active
    expect(str.request).to be_instance_of(Reel::H2::Stream::Request)
    str.__send__ :on_data, 'ohai'
    expect(str.request.body).to eq('ohai')
  end

  it 'calls handle_stream async on the server on half_close' do
    c = double 'connection'
    expect(c).to receive(:server).and_return(c)
    expect(c).to receive(:async).and_return(c)
    expect(c).to receive(:handle_stream).with(kind_of(Reel::H2::Stream))

    s = stream
    str = Reel::H2::Stream.new connection: c, stream: s
    str.__send__ :on_active
    str.__send__ :on_half_close
  end

end
