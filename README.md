![Reel](https://github.com/tarcieri/reel/raw/master/logo.png)
=======
[![Build Status](https://secure.travis-ci.org/tarcieri/reel.png?branch=master)](http://travis-ci.org/tarcieri/reel)

Reel is a fast, non-blocking/asynchronous web server built on
[http_parser.rb](https://github.com/tmm1/http_parser.rb) and
[Celluloid::IO](https://github.com/tarcieri/celluloid-io). It's probably
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
