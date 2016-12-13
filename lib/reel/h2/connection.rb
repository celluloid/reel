require 'http/2'

module Reel
  module H2

    # handles reading data from the +@socket+ into the +HTTP2::Server+ +@parser+,
    # callbacks from the +@parser+, and closing of the +@socket+
    #
    class Connection

      # each +@parser+ event method is wrapped in a block to call a local instance
      # method of the same name
      #
      PARSER_EVENTS = [
        :frame,
        :frame_sent,
        :frame_received,
        :stream,
        :goaway
      ]

      attr_reader :parser, :server, :socket

      def initialize socket:, server:
        @socket   = socket
        @server   = server
        @parser   = ::HTTP2::Server.new
        @attached = true

        yield self if block_given?

        bind_events

        Logger.debug "new H2::Connection: #{self}" if H2.verbose?
      end

      # is this connection still attached to the server reactor?
      #
      def attached?
        @attached
      end

      # bind parser events to this instance
      #
      def bind_events
        PARSER_EVENTS.each do |e|
          on = "on_#{e}".to_sym
          @parser.on(e) { |x| __send__ on, x }
        end
      end

      # closes this connection's socket if attached
      #
      def close
        socket.close if socket && attached?
      end

      # is this connection's socket closed?
      #
      def closed?
        socket.closed?
      end

      # prevent this server reactor from handling this connection
      #
      def detach
        @attached = false
        self
      end

      # accessor for stream handler
      #
      def each_stream &block
        @each_stream = block if block_given?
        @each_stream
      end

      # queue a goaway frame
      #
      def goaway
        server.async.goaway self
      end

      # begins the read loop, handling all errors with a log message,
      # backtrace, and closing the +@socket+
      #
      def read
        begin
          while attached? && !@socket.closed? && !(@socket.eof? rescue true)
            data = @socket.readpartial(4096)
            @parser << data
          end
          close

        rescue => e
          Logger.error "Exception: #{e.message} - closing socket"
          STDERR.puts e.backtrace
          close

        end
      end

      protected

      # +@parser+ event methods

      # called by +@parser+ with a binary frame to write to the +@socket+
      #
      def on_frame bytes
        Logger.debug "Writing bytes: #{truncate_string(bytes.unpack("H*").first)}" if Reel::H2.verbose?

        # N.B. this is the important bit
        #
        @socket.write bytes
      rescue IOError
        close
      end

      def on_frame_sent f
        Logger.debug "Sent frame: #{truncate_frame(f).inspect}" if Reel::H2.verbose?
      end

      def on_frame_received f
        Logger.debug "Received frame: #{truncate_frame(f).inspect}" if Reel::H2.verbose?
      end

      # the +@parser+ calls this when a new stream has been initiated by the
      # client
      #
      def on_stream stream
        Reel::H2::Stream.new connection: self, stream: stream
      end

      # the +@parser+ calls this when a goaway frame is received from the client
      #
      def on_goaway event
        close
      end

      private

      def truncate_string s
        (String === s && s.length > 64) ? "#{s[0,64]}..." : s
      end

      def truncate_frame f
        f.reduce({}) { |h, (k, v)| h[k] = truncate_string(v); h }
      end

    end
  end
end
