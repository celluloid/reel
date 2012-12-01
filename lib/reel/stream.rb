module Reel
  class Stream

    def initialize &proc
      @proc = proc
      @error_handlers = []
    end

    def call socket
      @socket = socket
      @proc.call self
    end

    def write data
      write!  data
      self
    end
    alias :<< :write

    # behaves like a true Rack::Response/BodyProxy object
    def each(*)
      yield self
    end

    def on_error &proc
      @error_handlers << proc
      self
    end

    def close
      @socket.close
    end
    alias finish close

    def closed?
      @socket.closed?
    end

    private
    def write! string
      @socket << string
    rescue => e
      @error_handlers.each {|h| h.call e}
    end

  end
    
  class EventStream < Stream

    # EventSource-related helpers
    #
    # @example
    #   Reel::EventStream.new do |socket|
    #     socket.event 'some event'
    #     socket.data 'some string'
    #     socket.retry 10
    #   end
    #
    # @note
    #   though retry is a reserved word, it is ok to use it as `object#retry`
    #
    %w[event data id retry].each do |meth|
      define_method meth do |data|
        write! meth + ": %s\n\n" % data # EventSource expects \n\n after each message
        self
      end
    end

  end
  
  class ChunkStream < Stream
    
    def write chunk
      chunk_header = chunk.bytesize.to_s(16)
      write! chunk_header + Response::CRLF
      write! chunk + Response::CRLF
      self
    end
    alias :<< :write

    # finish does not actually close the socket,
    # it only inform the browser there are no more messages
    def finish
      write! "0#{Response::CRLF * 2}"
    end

    def close
      finish
      super
    end

  end

  class StreamResponse < Response

    IDENTITY = 'identity'.freeze

    def initialize status, headers, body
      self.status = status
      @body = body

      case @body
      when EventStream
        # EventSource behaves extremely bad on chunked Transfer-Encoding
        headers[TRANSFER_ENCODING] = IDENTITY
      when ChunkStream
        headers[TRANSFER_ENCODING] = CHUNKED
      when Stream
      else
        raise TypeError, "can't render #{@body.class} as a response body"
      end

      @headers = canonicalize_headers(headers)
      @version = http_version
    end

    def render socket
      socket << render_header
      @body.call socket
    end
  end

end
