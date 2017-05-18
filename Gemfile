source 'https://rubygems.org'

ruby RUBY_VERSION

gem 'bundler'
gem 'celluloid'
gem 'celluloid-io'
gem 'http'

gem 'jruby-openssl' if defined? JRUBY_VERSION
gem 'coveralls', require: false

# Specify your gem's dependencies in reel.gemspec
gemspec

group :development do
  gem 'guard-rspec'
end

group :development, :test do
  gem 'pry'
end

group :test do
  gem 'certificate_authority'
  gem 'websocket_parser', '>= 0.1.6'
  gem 'rake'
  gem 'rspec'
end

platforms :rbx do
  gem 'racc'
  gem 'rubinius-coverage'
  gem 'rubysl', '~> 2.0'
end
