0.5.0
-----
* Pipelining support
* Reel::Request#body now returns a Reel::RequestBody object instead of a String
* New WebSocket API: obtain WebSockets through Reel::Request#websocket instead
  of through Reel::Connection#request. Allows processing of WebSockets through
  other means than the built-in WebSocket support

0.4.0
----
* Allow Reel to stop cleanly
* Remove `on_error` callback system
* Increase buffer size

0.3.0
-----
* Reel::App: Sinatra-like DSL for defining Reel apps using Octarine
* Chunked upload support
* Lots of additional work on the Rack adapter
* Expose websockets through Rack as rack.websocket
* Performance optimization work
* Bugfix: Send CRLF after chunks
* Bugfix: Increase TCP connection backlog to 1024

0.2.0
-----
* Initial WebSockets support via Reel::WebSocket
* Experimental Rack adapter by Alberto Fernández-Capel
* Octarine (Sinatra-like DSL) support by Grant Rodgers

0.1.0
-----
* Initial release
