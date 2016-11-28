module Reel
  module H2
    class Stream
      class Response

        CONTENT_LENGTH = 'content-length'.freeze

        attr_reader :body, :content_length, :headers, :status, :stream

        # build a new +Response+ object
        #
        def initialize stream:, status:, headers: {}, body: ''
          @stream     = stream
          @headers    = headers
          @body       = body
          self.status = status

          init_content_length
        end

        # sets the content length in the headers by the byte size of +@body+
        #
        def init_content_length
          @content_length = case @body
                            when String
                              @body.bytesize
                            when IO
                              @body.stat.size
                            when NilClass
                              '0'
                            else
                              raise TypeError, "can't render #{@body.class} as a response body"
                            end

          unless @headers.any? {|k,_| k.downcase == CONTENT_LENGTH}
            @headers[CONTENT_LENGTH] = @content_length
          end
        end

        # the corresponding +Request+ to this +Response+
        #
        def request
          stream.request
        end

        # send the headers and body out on +stream+
        #
        # NOTE: +:status+ must come first?
        #
        def respond_on s = stream
          headers = { Reel::H2::STATUS_KEY => @status.to_s }.merge @headers
          s.headers stringify_headers(headers)
          case @body
          when String
            s.data @body
          when IO
            raise NotImplementedError # TODO
          else
          end
        end

        # sets +@status+ either from given integer value (HTTP status code) or by
        # mapping a +Symbol+ in +Reel::Response::SYMBOL_TO_STATUS_CODE+ to one
        #
        def status= status
          case status
          when Integer
            @status = status
          when Symbol
            if code = Reel::Response::SYMBOL_TO_STATUS_CODE[status]
              self.status = code
            else
              raise ArgumentError, "unrecognized status symbol: #{status}"
            end
          else
            raise TypeError, "invalid status type: #{status.inspect}"
          end
        end

        def to_s
          %{#{request.addr} "#{request.method} #{request.path} HTTP/2" #{status} #{content_length}}
        end
        alias to_str to_s

        private

        def stringify_headers hash
          hash.keys.each do |k|
            if Symbol === k
              key = k.to_s.gsub '_', '-'
              hash[key] = hash.delete k
              k = key
            end
            hash[k] = hash[k].to_s unless String === hash[k]
          end
          hash
        end

      end
    end
  end
end
