require 'multipart_parser/parser'
require 'multipart_parser/reader'
require 'tempfile'

module Reel
  class Request
    include Celluloid::Internals::Logger

    CONTENT_TYPE = 'Content-Type'.freeze

    def multipart
      @multipart.decode if multipart?
    end

    def multipart?
      return @multipart.is_a? Reel::Request::Multipart if @multipart
      boundary = extract_boundary self.headers[CONTENT_TYPE]
      # initializing Multipart
      @multipart = Reel::Request::Multipart.new @body, boundary if boundary
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

        # configuring MultipartParser::Reader
        @reader.on_part do |part|
          # Streaming API So each file blob will contain information
          # regarding: data,part (for header and other information) and complete
          blob = {:data => Tempfile.new(part.name), :complete => false, :part => part }

          # adding file blob associating it with part.name
          @files[part.name] = blob

          # registering callback
          part.on_data { |data_chunk| blob[:data] << data_chunk }
          part.on_end do
            blob[:complete] = true
            blob[:data].rewind
            #TODO : expose part information if needed

          end
        end

        @reader.on_error{|msg| warn msg }

      end

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
