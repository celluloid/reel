![Reel](https://github.com/celluloid/reel/raw/master/logo.png)
=======
[![Gem Version](https://badge.fury.io/rb/reel.png)](http://rubygems.org/gems/reel)
[![Build Status](https://secure.travis-ci.org/celluloid/reel.png?branch=master)](http://travis-ci.org/celluloid/reel)
[![Dependency Status](https://gemnasium.com/celluloid/reel.png)](https://gemnasium.com/celluloid/reel)
[![Code Climate](https://codeclimate.com/github/celluloid/reel.png)](https://codeclimate.com/github/celluloid/reel)
[![Coverage Status](https://coveralls.io/repos/celluloid/reel/badge.png?branch=master)](https://coveralls.io/r/celluloid/reel)

> "A dizzying lifetime... Reeling by on Celluloid" _-- Rush / Between The Wheels_

Reel is a fast, non-blocking "evented" web server built on [http_parser.rb][parser],
[websocket_parser][websockets], [Celluloid::IO][celluloidio], and [nio4r][nio4r]. Thanks
to Celluloid, Reel also works great for multithreaded applications and provides
traditional multithreaded blocking I/O support too.

[parser]: https://github.com/tmm1/http_parser.rb
[websockets]: https://github.com/afcapel/websocket_parser
[celluloidio]: https://github.com/celluloid/celluloid-io
[nio4r]: https://github.com/celluloid/nio4r

Connections to Reel can be either non-blocking and handled entirely within
the Reel::Server thread, or the same connections can be dispatched to worker
threads where they will perform ordinary blocking IO. Reel provides no
built-in thread pool, however you can build one yourself using Celluloid.pool,
or because Celluloid already pools threads to begin with, you can simply use
an actor per connection.

This gives you the best of both worlds: non-blocking I/O for when you're
primarily I/O bound, and threads for where you're compute bound.

### Is it any good?

[Yes](http://news.ycombinator.com/item?id=3067434)

Here's a "hello world" web server benchmark, run on a 2GHz i7 (OS X 10.7.3).
All servers used in a single-threaded mode.

Reel performance on various Ruby VMs:

```
# httperf --num-conns=50 --num-calls=1000

Ruby Version        Throughput    Latency
------------        ----------    -------
JRuby 1.7.0         3978 req/s    (0.3 ms/req)
rbx HEAD            2288 reqs/s   (0.4 ms/req)
Ruby 1.9.3          2071 req/s    (0.5 ms/req)
```

Comparison with other web servers:

```
Web Server          Throughput    Latency
----------          ----------    -------
Goliath (0.9.4)     2058 reqs/s   (0.5 ms/req)
Thin    (1.2.11)    7502 reqs/s   (0.1 ms/req)
Node.js (0.6.5)     11735 reqs/s  (0.1 ms/req)
```

All Ruby benchmarks done on Ruby 1.9.3. Latencies given are average-per-request
and are not amortized across all concurrent requests.

API
---

Reel also provides a "bare metal" API which was used in the benchmarks above.
Here are some examples:

### Block Form

Reel lets you pass a block to initialize which receives connections:

```ruby
require 'reel'

Reel::Server.supervise("0.0.0.0", 3000) do |connection|
  while request = connection.request
    case request
    when Reel::Request
      puts "Client requested: #{request.method} #{request.url}"
      request.respond :ok, "Hello, world!"
    when Reel::WebSocket
      puts "Client made a WebSocket request to: #{request.url}"
      request << "Hello everyone out there in WebSocket land"
      request.close
      break
    end
  end
end

sleep
```

When we read a request from the incoming connection, we'll either get back
a Reel::Request object, indicating a normal HTTP connection, or a
Reel::WebSocket object for WebSockets connections.

### Subclass Form

You can also subclass Reel, which allows additional customizations:

```ruby
require 'reel'

class MyServer < Reel::Server
  def initialize(host = "127.0.0.1", port = 3000)
    super(host, port, &method(:on_connection))
  end

  def on_connection(connection)
    while request = connection.request
      case request
      when Reel::Request
        handle_request(request)
      when Reel::WebSocket
        handle_websocket(request)
      end
    end
  end

  def handle_request(request)
    request.respond :ok, "Hello, world!"
  end

  def handle_websocket(sock)
    sock << "Hello everyone out there in WebSocket land!"
    sock.close
  end
end

MyServer.run
```

Framework Adapters
------------------
### Rack

Reel can be used as a standard Rack server via the "reel" command line
application. Please be aware that Rack support is experimental and that there
are potential complications between using large numbers of rack middlewares
and the limited 4kB stack depth of Ruby Fibers, which are used extensively
by Celluloid. In addition, the Rack specification mandates that request bodies
are rewindable, which prevents streaming request bodies as the spec dictates
they must be written to disk.

To really leverage Reel's capabilities, you must use Reel via its own API,
or another Ruby library with direct Reel support.

### Webmachine

The most notable library with native Reel support is
[webmachine-ruby](https://github.com/seancribbs/webmachine-ruby),
an advanced HTTP framework for Ruby with a complete state machine for proper
processing of HTTP/1.1 requests. Together with Reel, Webmachine provides
full streaming support for both requests and responses.

To use Reel with Webmachine, add the following to your Gemfile:

```ruby
gem 'webmachine', git: 'git://github.com/seancribbs/webmachine-ruby.git'
```

Then use `config.adapter = :Reel` when configuring a Webmachine app, e.g:

```ruby
MyApp = Webmachine::Application.new do |app|
  app.routes do
    add ['*'], MyHome
  end

  app.configure do |config|
    config.ip      = MYAPP_IP
    config.port    = MYAPP_PORT
    config.adapter = :Reel

    # Optional: (WM master only) handler for incoming websockets
    config.adapter_options[:websocket_handler] = proc do |websocket|
      # socket is a Reel::WebSocket
      socket << "hello, world"
    end
  end
end

MyApp.run
```

See the [Webmachine documentation](http://rubydoc.info/gems/webmachine/frames/file/README.md)
for further information

Contributing
------------

* Fork this repository on github
* Make your changes and send me a pull request
* If I like them I'll merge them
* If I've accepted a patch, feel free to ask for commit access

License
-------

Copyright (c) 2012 Tony Arcieri. Distributed under the MIT License. See
LICENSE.txt for further details.
