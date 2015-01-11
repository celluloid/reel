source 'https://rubygems.org'

gem 'celluloid'
gem 'celluloid-io'
gem 'http'

gem 'jruby-openssl' if defined? JRUBY_VERSION
gem 'coveralls', require: false

# Specify your gem's dependencies in reel.gemspec
gemspec

group :development do
  gem 'guard-rspec'
  gem 'pry'
end

platforms :rbx do
  gem 'racc'
  gem 'rubinius-coverage'
  gem 'rubysl', '~> 2.0'
end
