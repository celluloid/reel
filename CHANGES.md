## 0.6.1 (2016-03-14)

* [#221](https://github.com/celluloid/reel/pull/221)
  Remove rack dependency. Add WebSocket ping forward.
  (**@kenichi**)

## 0.6.0 "Garland" (2016-02-13)

* [#214](https://github.com/celluloid/reel/pull/214):
  Fix ChunkStream termination.
  (**@ogoid**)

* [#182](https://github.com/celluloid/reel/pull/182):
  Do not allow transitioning out of closed.
  (**@zanker**)

* [#168](https://github.com/celluloid/reel/pull/168):
  Revert removal of addr and peeraddr delegates.
  (**@d-snp**)

* [#167](https://github.com/celluloid/reel/pull/167):
  Delegate #addr, #peeraddr, etc. methods in Spy.
  (**@d-snp**)

* [#166](https://github.com/celluloid/reel/pull/166):
  Switch to websocket-driver gem.
  (**@d-snp**)

* [#162](https://github.com/celluloid/reel/pull/162):
  Fix for #150: Reel::StateError: already processing
  a request when client is killed.
  (**@artcom**)

* [#155](https://github.com/celluloid/reel/pull/155):
  Handle Errno::ECONNRESET in SSL server.
  (**@czaks**)

* [#152](https://github.com/celluloid/reel/pull/152):
  Case insensitivity for header field names.
  (**@kenichi**)

* [#151](https://github.com/celluloid/reel/pull/151):
  Support for new http.rb gem API.
  (**@ixti**)

* [#148](https://github.com/celluloid/reel/pull/148):
  Fix stack level too deep when writing to ChunkStream.
  (**@bastjan**)

## 0.5.0 "Bette" (2014-04-15)

* Reel::Server(::SSL) renamed to Reel::Server::HTTP and Reel::Server::HTTPS
* New Reel::Spy API for observing requests and responses from the server
* Fixes to chunked encoding handling
* Update websocket_parser gem to 0.1.6
* Update to "The HTTP Gem" 0.6.0 
* Ensure response bodies are always closed
* Support for passing a fixnum status to Connection#respond

## 0.4.0 "Garbo"

* Rack adapter moved to the reel-rack project
* Pipelining support
* Reel::Connection#each_request for iterating through keep-alive requests
* Reel::Request#body now returns a Reel::RequestBody object instead of a String
* New WebSocket API: obtain WebSockets through Reel::Request#websocket instead
  of through Reel::Connection#request. Allows processing of WebSockets through
  other means than the built-in WebSocket support
* Allow Reel to stop cleanly
* Remove `on_error` callback system
* Increase buffer size
* Remove Reel::App (unmaintained, sorry)
* Reel::CODENAME added (0.4.0 is "Garbo")

## 0.3.0

* Reel::App: Sinatra-like DSL for defining Reel apps using Octarine
* Chunked upload support
* Lots of additional work on the Rack adapter
* Expose websockets through Rack as rack.websocket
* Performance optimization work
* Bugfix: Send CRLF after chunks
* Bugfix: Increase TCP connection backlog to 1024

## 0.2.0

* Initial WebSockets support via Reel::WebSocket
* Experimental Rack adapter by Alberto Fernández-Capel
* Octarine (Sinatra-like DSL) support by Grant Rodgers

## 0.1.0

* Initial release
