module Reel
  
  class Stream

    def initialize &proc
      @proc = proc
    end

    def call socket
      @socket = socket
      @proc.call self
    end

    # writing data directly to socket
    def write data
      @socket << data
      self
    end
    alias :<< :write
    alias :push :write

    def close
      @socket.close unless @socket.closed?
    end
    alias finish close

  end
    
  class EventStream < Stream

    # helpers
    # @example - using helpers
    #   Reel::EventStream.new do |socket|
    #     socket.event 'some event'
    #     socket.data 'some string'
    #   end
    %w[event data id retry].each do |meth|
      define_method meth do |data|
        push meth + ': ' + data
      end
    end

    # EventSource expects \n\n after each message
    def push data
      write data.to_s + "\n\n"
    end

  end
  
  class ChunkStream < Stream
    
    def write chunk
      chunk_header = (chunk = chunk.to_s).bytesize.to_s(16)
      @socket << chunk_header + Response::CRLF
      @socket << chunk + Response::CRLF
    end
    alias :<< :write
    alias :push :write

    # finish does not actually close the socket,
    # it only inform the browser there are no more messages
    def finish
      @socket << "0#{Response::CRLF * 2}"
    end

    def close
      finish
      super
    end

  end

end
