module Reel
  module H2
    class Stream

      # each stream event method is wrapped in a block to call a local instance
      # method of the same name
      #
      STREAM_EVENTS = [
        :active,
        :close,
        :half_close
      ]

      # the above take only the event, the following receive both the event
      # and the data
      #
      STREAM_DATA_EVENTS = [
        :headers,
        :data
      ]

      CONTENT_TYPE = 'content-type'

      attr_reader :connection,
                  :push_promises,
                  :request,
                  :response,
                  :stream

      def initialize connection:, stream:
        @completed     = false
        @connection    = connection
        @push_promises = Set.new
        @responded     = false
        @stream        = stream

        bind_events
      end

      # mimicing Reel::Connection#respond
      #
      # write status, headers, and data to +@stream+
      #
      def respond response, body_or_headers = nil, body = nil

        # :/
        #
        if Hash === body_or_headers
          headers = body_or_headers
          body ||= ''
        else
          headers = {}
          body = body_or_headers ||= ''
        end

        @response = case response
                    when Symbol, Integer
                      response = Response.new stream: self,
                                              status: response,
                                              headers: headers,
                                              body: body
                    when Response
                      response
                    else raise TypeError, "invalid response: #{response.inspect}"
                    end

        response.respond_on(stream)
        log :info, response

        @responded = true
        on_complete
      end

      # create a push promise, send the headers, then queue an asynchronous
      # task on the reactor to deliver the data
      #
      def push_promise *args
        pp = push_promise_for *args
        make_promise pp
        @connection.server.async.handle_push_promise pp
      end

      # create a push promise - mimicing Reel::Connection#respond
      #
      def push_promise_for path, body_or_headers = {}, body = nil

        # :/
        #
        case body_or_headers
        when Hash
          headers = body_or_headers
        else
          headers = {}
          body = body_or_headers
        end

        headers.merge! AUTHORITY_KEY => @request.authority,
                       SCHEME_KEY    => @request.scheme

        PushPromise.new path, headers, body
      end

      # begin the new push promise stream from this +@stream+ by sending the
      # initial headers frame
      #
      # @see +PushPromise#make_on!+
      # @see +HTTP2::Stream#promise+
      #
      def make_promise p
        p.make_on self
        push_promises << p
        p
      end

      # set or call +@complete+ callback
      #
      def on_complete &block
        return true if @completed
        if block
          @complete = block
        elsif @completed = (@responded and push_promises_complete?)
          @complete[] if Proc === @complete
          true
        else
          false
        end
      end

      # check for push promises completion
      #
      def push_promises_complete?
        @push_promises.empty? or @push_promises.all? {|p| p.kept? or p.canceled?}
      end

      # trigger a GOAWAY frame when this stream is responded to and any/all push
      # promises are complete
      #
      def goaway_on_complete
        on_complete { connection.goaway }
      end

      # logging helper
      #
      def log level, msg
        Logger.__send__ level, "[stream #{@stream.id}] #{msg}"
      end

      protected

      # bind parser events to this instance
      #
      def bind_events
        STREAM_EVENTS.each do |e|
          on = "on_#{e}".to_sym
          @stream.on(e) { __send__ on }
        end
        STREAM_DATA_EVENTS.each do |e|
          on = "on_#{e}".to_sym
          @stream.on(e) { |x| __send__ on, x }
        end
      end

      # called by +@stream+ when this stream is activated
      #
      def on_active
        log :debug, 'active' if Reel::H2.verbose?
        @request = Reel::H2::Stream::Request.new self
      end

      # called by +@stream+ when this stream is closed
      #
      def on_close
        log :debug, 'close' if Reel::H2.verbose?
      end

      # called by +@stream+ with a +Hash+
      #
      def on_headers h
        incoming_headers = Hash[h]
        log :debug, "headers: #{incoming_headers}" if Reel::H2.verbose?
        @request.headers.merge! incoming_headers
      end

      # called by +@stream+ with a +String+ body part
      #
      def on_data d
        log :debug, "data: <<#{d}>>" if Reel::H2.verbose?
        @request.body << d
      end

      # called by +@stream+ when body/request is complete, signaling that client
      # is ready for response(s)
      #
      def on_half_close
        log :debug, 'half_close' if Reel::H2.verbose?
        connection.server.async.handle_stream self
      end

    end
  end
end
