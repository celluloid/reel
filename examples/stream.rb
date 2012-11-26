require 'rubygems'
require 'bundler/setup'
require 'reel'

app = Rack::Builder.new do
  map '/' do
    run lambda { |env|
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
    }
  end
end.to_app

Rack::Handler::Reel.run app, Port: 9292
