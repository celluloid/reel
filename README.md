![Reel](https://github.com/celluloid/reel/raw/master/logo.png)
=======
[![Build Status](https://secure.travis-ci.org/celluloid/reel.png?branch=master)](http://travis-ci.org/celluloid/reel)

Reel is a fast, non-blocking "evented" web server built on [http_parser.rb][parser],
[websocket_parser][websockets], [Celluloid::IO][celluloidio], and [nio4r][nio4r]. Thanks
to Celluloid, Reel also works great for multithreaded applications and provides
traditional multithreaded blocking I/O support too.

[parser]: https://github.com/tmm1/http_parser.rb
[websockets]: https://github.com/afcapel/websocket_parser
[celluloidio]: https://github.com/celluloid/celluloid-io
[nio4r]: https://github.com/tarcieri/nio4r

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
JRuby HEAD          5650 reqs/s   (0.2 ms/req)
Ruby 1.9.3          5263 reqs/s   (0.2 ms/req)
JRuby 1.6.7         4303 reqs/s   (0.2 ms/req)
rbx HEAD            2288 reqs/s   (0.4 ms/req)
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

Usage
-----

Reel provides an extremely simple API:

```ruby
require 'reel'

Reel::Server.supervise("0.0.0.0", 3000) do |connection|
  while request = connection.request
    case request
    when Reel::Request
      puts "Client requested: #{request.method} #{request.url}"
      connection.respond :ok, "hello, world"
    when Reel::WebSocket
      puts "Client made a WebSocket request to: #{request.url}"
      request << "Hello there"
      connection.close
      break
    end
  end
end
```

When we read a request from the incoming connection, we'll either get back
a Reel::Request object, indicating a normal HTTP connection, or a
Reel::WebSocket object for WebSockets connections.

Status
------

Reel is still in an extremely early stage of development and may be
missing a lot of features. It seems to be doing a rudimentary job of
speaking HTTP and has basic keep-alive support.

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
