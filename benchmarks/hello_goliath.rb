# Run with: ruby hello_goliath.rb -sv -e production
require 'goliath'

class Hello < Goliath::API
  # default to JSON output, allow Yaml as secondary
  use Goliath::Rack::Render, ['json', 'yaml']

  def response(env)
    [200, {}, "Hello World"]
  end
end
