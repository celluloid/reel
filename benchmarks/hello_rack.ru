# Run with: thin -e production -R hello_rack.ru start
require 'rack'

body = "Hello World"
run proc { |env| [200, {}, body] }
