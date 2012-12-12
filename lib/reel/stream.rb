module Reel
  class Stream

    def initialize &proc
      @proc = proc
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
      @on_error = proc
      self
    end

    def close
      @socket.close unless closed?
    end
    alias finish close

    def closed?
      @socket.closed?
    end

    private
    def write! string
      @socket << string
    rescue => e
      @on_error ? @on_error.call(e) : raise(e)
    end

  end
    
  class EventStream < Stream

    # EventSource-related helpers
    #
    # @example
    #   Reel::EventStream.new do |socket|
    #     socket.event 'some event'
    #     socket.retry 10
    #   end
    #
    # @note
    #   though retry is a reserved word, it is ok to use it as `object#retry`
    #
    %w[event id retry].each do |meth|
      define_method meth do |data|
        # unlike on #data, these messages expects a single \n at the end.
        write! "%s: %s\n" % [meth, data]
      end
    end

    def data data
      # - any single message should not contain \n except at the end.
      # - EventSource expects \n\n at the end of each single message.
      write! "data: %s\n\n" % data.gsub(/\n|\r/, '')
      self
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
