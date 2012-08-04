require 'spec_helper'

describe Reel::Configuration do

  it "accepts an option to set the port" do
    Reel::Configuration.new(['-p', '2000'])[:port].should == 2000
    Reel::Configuration.new(['--port', '1000'])[:port].should == 1000
  end

  it "accepts an option to set the host" do
    Reel::Configuration.new(['-a', '192.168.1.1'])[:host].should == '192.168.1.1'
    Reel::Configuration.new(['--address', '192.168.1.1'])[:host].should == '192.168.1.1'
  end

  it "accepts an option to be quiet" do
    Reel::Configuration.new(['-q'])[:quiet].should be_true
    Reel::Configuration.new(['--quiet'])[:port].should be_true
  end

  it "accepts an option to set the environment" do
    Reel::Configuration.new(['-e', 'production'])[:environment].should == 'production'
    Reel::Configuration.new(['--environment', 'production'])[:environment].should == 'production'
  end

  it "accepts an option to set the number of worker threads" do
    Reel::Configuration.new(['-t', '30'])[:workers].should == 30
    Reel::Configuration.new(['--threads', '30'])[:workers].should == 30
  end

  it "accepts an option to set the rackup file" do
    Reel::Configuration.new(['-r', 'app.ru'])[:rackup].should == 'app.ru'
    Reel::Configuration.new(['--rackup', 'app.ru'])[:rackup].should == 'app.ru'
  end

end