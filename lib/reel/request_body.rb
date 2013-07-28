module Reel
  # Represents the bodies of Requests
  class RequestBody
    def initialize(request)
      @request   = request
      @streaming = nil
      @contents  = nil
    end

    # Read exactly the given amount of data
    def read(length)
      stream!
      @request.read(length)
    end

    # Read up to length bytes, but return any data that's available
    def readpartial(length = nil)
      stream!
      @request.readpartial(length)
    end

    # Eagerly consume the entire body as a string
    def to_s
      return @contents if @contents
      raise StateError, "body is being streamed" unless @streaming.nil?

      begin
        @streaming = false
        @contents = ""
        while chunk = @request.readpartial
          @contents << chunk
        end
      rescue
        @contents = nil
        raise
      end

      @contents
    end

    # Assert that the body is actively being streamed
    def stream!
      raise StateError, "body has already been consumed" if @streaming == false
      @streaming = true
    end
  end
end
