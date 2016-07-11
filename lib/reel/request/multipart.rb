require 'multipart_parser/parser'
require 'multipart_parser/reader'

module Reel
  class Request
    include Celluloid::Internals::Logger

    CONTENT_TYPE = 'Content-Type'.freeze

    def multipart
      @multipart.decode if multipart? @body
    end

    def multipart? body=nil
      return @multipart.is_a? Reel::Request::Multipart if @multipart or body.nil?
      boundary = extract_boundary self.headers[CONTENT_TYPE]
      # initializing Multipart
      @multipart = Reel::Request::Multipart.new body,boundary if boundary
      @multipart.is_a? Reel::Request::Multipart
    rescue => e
      info e.to_s
      @multipart = false
    end

    def extract_boundary content
      MultipartParser::Reader.extract_boundary_value content
    end

    class Multipart
      extend Forwardable

      def initialize(body,boundary)
        @files = {}
        @body = body
        @boundary = boundary
        @reader = MultipartParser::Reader.new(@boundary)
        # TODO configure MultipartParser::Reader callbacks
      end

      # delegating MultipartParser::Reader to write and parse chunks
      def_delegators :@reader, :write

      def decode
        return @files if @files.any?
        begin
          @body.each { |chunks| write chunks }
        rescue => e
          info e.to_s
          @files = {}
        end
        @files
      end

    end

  end
end
