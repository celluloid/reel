require 'multipart_parser/parser'
require 'multipart_parser/reader'

module Reel
  class Request
    CONTENT_TYPE = 'Content-Type'.freeze

    def multipart
      @multipart.decode
    end

    def multipart? body=nil
      return @multipart.is_a? Reel::Request::Multipart if @multipart or body.nil?
      boundary = extract_boundary self.headers[CONTENT_TYPE]
      # initializing Multipart
      @multipart = Reel::Request::Multipart.new body,boundary if boundary
      @multipart.is_a? Reel::Request::Multipart
    end

    def extract_boundary content
      MultipartParser::Reader.extract_boundary_value content
    end

    class Multipart

      def initialize(body,boundary)
        # TODO
      end

      def decode
        #TODO
      end

    end
  end
end
