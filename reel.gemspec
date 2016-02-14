# -*- encoding: utf-8 -*-
require File.expand_path("../culture/sync", __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tony Arcieri", "digitalextremist //"]
  gem.email         = ["tony.arcieri@gmail.com", "code@extremist.digital"]
  gem.description   = "A Celluloid::IO-powered multi-protocol HTTP, HTTPS, and Web Socket server"
  gem.summary       = "A Reel good web server"
  gem.homepage      = "https://github.com/celluloid/reel"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "reel"
  gem.require_paths = ["lib"]
  gem.version       = Reel::VERSION

  gem.add_runtime_dependency 'celluloid-io', '>= 0.16.5.pre0'

  Celluloid::Sync::Gemspec[gem]

  gem.add_runtime_dependency 'http', '>= 0.6.0.pre'
  gem.add_runtime_dependency 'http_parser.rb', '>= 0.6.0'
  gem.add_runtime_dependency 'websocket-driver', '>= 0.5.1'
  gem.add_runtime_dependency 'websocket_parser', '>= 0.1.6'

  gem.add_development_dependency 'certificate_authority'
end
