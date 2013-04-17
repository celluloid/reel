require 'spec_helper'
require 'reel/app'

describe Reel::App do
  let(:app) {
    Class.new do
      include Reel::App

      get example_path do
        [200, {}, "hello foo"]
      end

    end
  }

  before(:each) do
    @app = app.new(example_addr, example_port)
  end

  after(:each) do
    @app.server.terminate if @app && @app.server.alive?
  end

  it 'responds to get requests' do
    res = Http.with_response(:object).get example_url
    res.status.should == 200
    res.headers.should == {"Content-Length" => res.body.length.to_s}
    res.body.should == "hello foo"
  end

  it 'terminates the server' do
    @app.terminate
    @app.server.should_not be_alive
  end
end
