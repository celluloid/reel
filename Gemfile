source 'https://rubygems.org'

ruby RUBY_VERSION

gem 'jruby-openssl' if defined? JRUBY_VERSION

# Specify your gem's dependencies in reel.gemspec
gemspec

group :development, :test do
  gem 'coveralls', require: false
  gem 'guard-rspec', require: false
  gem 'pry-byebug'
end

group :test do
  gem 'certificate_authority'
  gem 'websocket_parser', '>= 0.1.6'
  gem 'rake'
  gem 'rspec'
  gem 'coveralls', require: false
  gem 'h2', git: 'https://github.com/kenichi/h2'
end
