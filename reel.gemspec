# -*- encoding: utf-8 -*-
require File.expand_path('../lib/reel/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tony Arcieri"]
  gem.email         = ["tony.arcieri@gmail.com"]
  gem.description   = "A Celluloid::IO-powered HTTP server"
  gem.summary       = "A reel good HTTP server"
  gem.homepage      = "https://github.com/celluloid/reel"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "reel"
  gem.require_paths = ["lib"]
  gem.version       = Reel::VERSION

  gem.add_runtime_dependency 'celluloid-io',     '>= 0.8.0'
  gem.add_runtime_dependency 'http',             '>= 0.2.0'
  gem.add_runtime_dependency 'http_parser.rb',   '>= 0.5.3'
  gem.add_runtime_dependency 'websocket_parser', '>= 0.0.2'
  gem.add_runtime_dependency 'rack',             '>= 1.4.0'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
end
