require File.expand_path("../culture/sync", __FILE__)
Celluloid::Sync::Gemfile[self]

gem 'jruby-openssl' if RUBY_PLATFORM == 'java'
gem 'celluloid-io', github: 'celluloid/celluloid-io', branch: '0.17.0-dependent', submodules: true

gem 'http'
gem 'http-2'

# Specify your gem's dependencies in reel.gemspec
gemspec

platforms :rbx do
  gem 'racc'
  gem 'rubinius-coverage'
  gem 'rubysl', '~> 2.0'
end
