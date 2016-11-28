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
        @connection    = connection
        @stream        = stream
        @push_promises = Set.new

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

        @response.respond_on(@stream)
        log :info, @response
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

      private

      # --- logging helpers

      def log level, msg
        Logger.__send__ level, "[stream #{@stream.id}] #{msg}"
      end

    end
  end
end
