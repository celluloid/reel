require File.expand_path("../culture/sync", __FILE__)
source 'https://rubygems.org'

gem 'jruby-openssl' if RUBY_PLATFORM == 'java'

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

Celluloid::Sync.gems(self)
