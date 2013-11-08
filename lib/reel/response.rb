require 'reel/response/writer'

module Reel
  class Response
    include HTTP::Header

    CONTENT_LENGTH     = 'Content-Length'.freeze
    TRANSFER_ENCODING  = 'Transfer-Encoding'.freeze
    CHUNKED            = 'chunked'.freeze

    # Use status code tables from the HTTP gem
    STATUS_CODES          = HTTP::Response::STATUS_CODES
    SYMBOL_TO_STATUS_CODE = HTTP::Response::SYMBOL_TO_STATUS_CODE

    attr_reader   :status # Status has a special setter to coerce symbol names
    attr_accessor :reason # Reason can be set explicitly if desired
    attr_reader   :headers, :body, :version

    def initialize(status, body_or_headers = nil, body = nil)
      self.status = status

      if body_or_headers.is_a?(Hash)
        headers = body_or_headers.dup
        @body = body
      else
        headers = {}
        @body = body_or_headers
      end

      case @body
      when String
        headers[CONTENT_LENGTH] ||= @body.bytesize
      when IO
        headers[CONTENT_LENGTH] ||= @body.stat.size
      when Enumerable
        headers[TRANSFER_ENCODING] ||= CHUNKED
      when NilClass
      else raise TypeError, "can't render #{@body.class} as a response body"
      end

      @headers = canonicalize_headers(headers)
      @version = http_version
    end

    def chunked?
      headers[TRANSFER_ENCODING] == CHUNKED
    end

    # Set the status
    def status=(status, reason=nil)
      case status
      when Integer
        @status = status
        @reason ||= STATUS_CODES[status]
      when Symbol
        if code = SYMBOL_TO_STATUS_CODE[status]
          self.status = code
        else
          raise ArgumentError, "unrecognized status symbol: #{status}"
        end
      else
        raise TypeError, "invalid status type: #{status.inspect}"
      end
    end

    def canonicalize_headers(headers)
      headers.inject({}) do |headers, (header, value)|
        headers.merge canonicalize_header(header) => value.to_s
      end.freeze
    end
    private :canonicalize_headers

    def http_version
      # FIXME: real HTTP versioning
      "HTTP/1.1".freeze
    end
    private :http_version
  end
end
