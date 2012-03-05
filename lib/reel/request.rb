module Reel
  class Request
    attr_accessor :method, :version, :url
    METHODS = [:get, :head, :post, :put, :delete, :trace, :options, :connect, :patch]
    
    def initialize(method, url, version = "1.1", headers = {}, &body_chunk)
      @method = method.to_s.downcase.to_sym
      raise UnsupportedArgumentError, "unknown method: #{method}" unless METHODS.include? @method
      
      @url, @version, @headers = url, version, headers
      @body_proc = body_chunk
    end
    
    def [](header)
      @headers[header]
    end
    
    def body
      @body ||= begin
        body = "" unless block_given?
        while chunk = @body_proc.call
          if block_given?
            yield chunk
          else
            body << chunk
          end
        end
        body unless block_given?
      end
    end
  end
end