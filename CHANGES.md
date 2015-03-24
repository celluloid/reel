0.6.0
----
* Fix stack level too deep when writing to ChunkStream
* Use HTTP::Resonse::Status::REASONS table ( HTTP::Response::* deprecated in the HTTP gem )
* Use Timers 3.0.0 API
* Case-insensitivity for header field names ( i.e. in case a proxy downcases them )
* Catch when openssl sometimes fires ECONNRESET, EPIPE, ETIMEDOUT, EHOSTUNREACH and  as an error
* Unused `optimize` socket modifications taken off all server implementations
* Fixed 404 error in roundtrip example
* Fixed "Reel::StateError: already processing a request" when client is killed
* Numerous updates to rspec.
* Switched to websocket/driver and improved websocket handling
* Implement DriverEnvironment to fix websocket example
* Refactored Server::HTTPS to be more idomatic
* Fixed jRuby related test failures
* Fixed "ArgumentError: Data object has already been freed" caused by underlying parser.

0.5.0 (2014-04-15)
----
* Reel::Server(::SSL) renamed to Reel::Server::HTTP and Reel::Server::HTTPS
* New Reel::Spy API for observing requests and responses from the server
* Fixes to chunked encoding handling
* Update websocket_parser gem to 0.1.6
* Update to "The HTTP Gem" 0.6.0 
* Ensure response bodies are always closed
* Support for passing a fixnum status to Connection#respond

0.4.0
-----
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
