module Reel
  class RequestParser
    def initialize
      @parser = Http::Parser.new(self)
    end

    def add(data)
      @parser << data
    end
    alias_method :<<, :add

    def on_headers_complete(headers)
      puts "Got headers: #{headers.inspect}"
    end

    def on_body(chunk)
      puts "[BODY] #{chunk}"
    end

    def on_message_complete
      puts "DONE!"
    end    
  end
end