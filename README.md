![Reel](https://github.com/celluloid/reel/raw/master/logo.png)
=======
[![Build Status](https://secure.travis-ci.org/celluloid/reel.png?branch=master)](http://travis-ci.org/tarcieri/reel)

Reel is a fast, non-blocking "evented" web server built on
[http_parser.rb](https://github.com/tmm1/http_parser.rb) and
[Celluloid::IO](https://github.com/celluloid/celluloid-io). It's probably
most similar to [Goliath](http://postrank-labs.github.com/goliath/), but thanks
to Celluloid can be easily composed with multithreaded applications.

Connections to Reel can be either non-blocking and handled entirely within
the Reel::Server thread, or the same connections can be dispatched to worker
threads where they will perform ordinary blocking IO. Reel provides no
built-in thread pool, however you can build one yourself using Celluloid::Pool,
or because Celluloid already pools threads to begin with, you can simply use
an actor per connection.

This gives you the best of both worlds: non-blocking I/O for when you're
primarily I/O bound, and threads for where you're compute bound.

### Is It Good?

Yes, but it has room for improvement. A "hello world" web server benchmark,
run on a 2GHz i7 (OS X 10.7.3). All servers used in a single-threaded mode.

Reel performance on various Ruby VMs:

```
# httperf --num-conns=50 --num-calls=1000

Ruby Version        Throughput    Latency
------------        ----------    -------
Ruby 1.9.3          5263 reqs/s   (0.2 ms/req)
JRuby 1.6.7         4024 reqs/s   (0.2 ms/req)
JRuby HEAD          5478 reqs/s   (0.2 ms/req)
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
  request = connection.request
  puts "Client requested: #{request.method} #{request.url}"
  connection.respond :ok, "hello, world"
end
```

Status
------

Reel is mostly in the proof of concept stage, working well enough you can
point your favorite benchmarking utility at it, but not exactly speaking
valid HTTP yet.

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
