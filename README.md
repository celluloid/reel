![Reel](https://github.com/celluloid/reel/raw/master/logo.png)
=======
[![Gem Version](https://badge.fury.io/rb/reel.svg)](http://rubygems.org/gems/reel)
[![Build Status](https://secure.travis-ci.org/celluloid/reel.svg?branch=master)](http://travis-ci.org/celluloid/reel)
[![Code Climate](https://codeclimate.com/github/celluloid/reel.svg)](https://codeclimate.com/github/celluloid/reel)
[![Coverage Status](https://coveralls.io/repos/celluloid/reel/badge.svg?branch=master)](https://coveralls.io/r/celluloid/reel)
[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/celluloid/reel/master/LICENSE.txt)

> "A dizzying lifetime... reeling by on celluloid" _-- Rush / Between The Wheels_

Reel is a fast, non-blocking "evented" web server
built on [http_parser.rb][parser], [websocket_parser][websockets],
[Celluloid::IO][celluloidio], and [nio4r][nio4r]. Thanks to Celluloid,
Reel also works great for multithreaded applications
and provides traditional multithreaded blocking I/O support too.

[parser]: https://github.com/tmm1/http_parser.rb
[websockets]: https://github.com/afcapel/websocket_parser
[celluloidio]: https://github.com/celluloid/celluloid-io
[nio4r]: https://github.com/celluloid/nio4r

Connections to Reel can be either non-blocking and handled entirely within
the Reel::Server thread (handling HTTP, HTTPS, or UNIX sockets),
or the same connections can be dispatched to worker threads
where they will perform ordinary blocking IO.
Reel provides no built-in thread pool,
however you can build one yourself using Celluloid.pool,
or because Celluloid already pools threads to begin with,
you can simply use an actor per connection.

This gives you the best of both worlds: non-blocking I/O for when you're
primarily I/O bound, and threads for where you're compute bound.

### Is it any good?

[Yes](http://news.ycombinator.com/item?id=3067434)

Documentation
-------------

[Please see the Reel Wiki](https://github.com/celluloid/reel/wiki)
for detailed documentation and usage notes.

[YARD documentation](http://rubydoc.info/github/celluloid/reel/master/frames) is
also available.

Framework Adapters
------------------

### Rack

A Rack adapter for Reel is available at:

https://github.com/celluloid/reel-rack

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

    # Optional: handler for incoming websockets
    config.adapter_options[:websocket_handler] = proc do |websocket|
      # websocket is a Reel::WebSocket
      websocket << "hello, world"
    end
  end
end

MyApp.run
```

See the [Webmachine documentation](http://rubydoc.info/gems/webmachine/frames/file/README.md)
for further information

Ruby API
--------

Reel aims to provide a "bare metal" API that other frameworks (such as Rack
and Webmachine) can leverage. This API can also be nice in performance critical
applications.

### Block Form

Reel lets you pass a block to initialize which receives connections:

```ruby
require 'celluloid/autostart'
require 'reel'

Reel::Server::HTTP.supervise("0.0.0.0", 3000) do |connection|
  # Support multiple keep-alive requests per connection
  connection.each_request do |request|
    # WebSocket support
    if request.websocket?
      puts "Client made a WebSocket request to: #{request.url}"
      websocket = request.websocket

      websocket << "Hello everyone out there in WebSocket land"
      websocket.close
    else
      puts "Client requested: #{request.method} #{request.url}"
      request.respond :ok, "Hello, world!"
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
require 'celluloid/autostart'
require 'reel'

class MyServer < Reel::Server::HTTP
  def initialize(host = "127.0.0.1", port = 3000)
    super(host, port, &method(:on_connection))
  end

  def on_connection(connection)
    connection.each_request do |request|
      if request.websocket?
        handle_websocket(request.websocket)
      else
        handle_request(request)
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

Supported Ruby Versions
-----------------------

This library supports and is tested against the following Ruby versions:

* Ruby (MRI) 2.0, 2.1, 2.2, 2.3
* JRuby 9000

Contributing
------------

* Fork this repository on GitHub
* Make your changes and send us a pull request
* If we like them we'll merge them
* If we've accepted a patch, feel free to ask for commit access

License
-------

Copyright (c) 2012-2016 Tony Arcieri. Distributed under the MIT License. See
LICENSE.txt for further details.
