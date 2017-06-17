source 'https://rubygems.org'

ruby RUBY_VERSION

gem 'jruby-openssl' if defined? JRUBY_VERSION

# Specify your gem's dependencies in reel.gemspec
gemspec

group :development, :test do
  gem 'h2', git: 'https://github.com/kenichi/h2'
  gem 'coveralls', require: false
  gem 'guard-rspec', require: false
  gem 'pry-byebug', platforms: [:mri]
end
