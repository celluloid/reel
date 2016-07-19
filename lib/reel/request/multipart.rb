require 'multipart_parser/parser'
require 'multipart_parser/reader'

module Reel
  class Request
    include Celluloid::Internals::Logger

    CONTENT_TYPE = 'Content-Type'.freeze

    def multipart
      @multipart.decode if multipart? @body
    end

    def multipart?(body = nil)
      return @multipart.is_a? Reel::Request::Multipart if @multipart || body.nil?
      boundary = extract_boundary self.headers[CONTENT_TYPE]
      # initializing Multipart
      @multipart = Reel::Request::Multipart.new body, boundary if boundary
      @multipart.is_a? Reel::Request::Multipart
    rescue => e
      warn e
      @multipart = false
    end

    def extract_boundary(content)
      MultipartParser::Reader.extract_boundary_value content
    end

    class Multipart
      extend Forwardable

      def initialize(body, boundary)
        @files = {}
        @body = body
        @boundary = boundary
        @reader = MultipartParser::Reader.new(@boundary)

        # configuring MultipartParser::Reader callbacks
        @reader.on_part do |part|
          # Streaming API So each file blob will contain information regarding data, ended?
          blob = {:data => "", :ended => false, :part => part }

          # adding file blob associating it with part.name
          @files[part.name] = blob

          # registering callback
          part.on_data { |data_chunk| blob[:data] << data_chunk }
          part.on_end { blob[:ended] = true }
        end

        @reader.on_error{|msg| warn msg }

      end

      # delegating MultipartParser::Reader to write and parse chunks
      def_delegators :@reader, :write

      def decode
        return @files if @files.any?
        begin
          @body.each { |chunks| write chunks }
        rescue => e
          warn e
          @files = {}
        end
        @files
      end

    end

  end
end
