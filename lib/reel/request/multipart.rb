require 'multipart_parser/parser'
require 'multipart_parser/reader'
require 'tempfile'

module Reel
  class Request
    include Celluloid::Internals::Logger

    CONTENT_TYPE = 'Content-Type'.freeze

    # if multipart type
    #   return Hash :
    #   {
    #     key1 => {
    #       :data => Tempfile object,
    #       :complete => true/false,
    #       :part => part object (header info etc)
    #     },
    #    key2 => {...}
    #   }
    # if not multipart type
    #   return nil
    def multipart
      @multipart.decode if multipart?
    end

    # utility function to check if Content-Type is a multipart type
    # and initializing @multipart
    def multipart?
      return @multipart.is_a? Reel::Request::Multipart if @multipart
      # extract boundary
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
          if part.filename
            blob = {:data => Tempfile.new(part.filename), :complete => false, :part => part }
          else
            blob = {:data => "", :complete => false, :part => part}
          end
          # adding file blob associating it with part.name
          @files[part.name] = blob

          # registering callback
          part.on_data { |data_chunk| blob[:data] << data_chunk }
          part.on_end do
            blob[:complete] = true
            blob[:data].rewind if blob[:data].is_a? Tempfile
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
