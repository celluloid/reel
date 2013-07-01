source 'https://rubygems.org'

gem 'celluloid',    github: 'celluloid/celluloid',    branch: 'master'
gem 'celluloid-io', github: 'celluloid/celluloid-io', branch: 'master'
gem 'websocket-protocol', github: 'faye/websocket-protocol-ruby', branch: 'master'

gem 'rack', github: 'rack/rack', branch: 'master'

gem 'jruby-openssl' if defined? JRUBY_VERSION
gem 'coveralls', require: false

# Specify your gem's dependencies in reel.gemspec
gemspec

group :development do
  gem 'guard-rspec'
  gem 'pry'
end
