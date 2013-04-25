require 'rubygems'
require 'bundler/setup'
require 'reel'
require 'reel/app'

class Streamer
  include Reel::App

  get '/' do
    body = Reel::Stream.new do |body|
      # sending a payload to make sure browsers will render chunks as received
      body << "<html>#{' '*1024}\n"
      ('A'..'Z').each do |l|
        body << "<div>#{l}</div>\n"
        sleep 0.5
      end
      body << "</html>\n"
      body.finish
    end
    [200, {
      'Transfer-Encoding' => 'identity',
      'Content-Type' => 'text/html'
    }, body]
  end
end

Streamer.new("0.0.0.0", 9292)
sleep
