module Reel
  class StreamingResponse < Response
    def initialize(*args)
      super(*args)
      @headers.delete 'Content-Length'
      @headers['Transfer-Encoding'] = 'chunked'
    end

    def render(socket)
      socket << render_header
      ChunkedBody.new(@body).each {|chunk| socket << chunk }
    end
  end
end
