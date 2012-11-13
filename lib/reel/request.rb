require 'uri'

module Reel
  class Request
    attr_accessor :method, :version, :url, :headers

    UPGRADE   = 'Upgrade'.freeze
    WEBSOCKET = 'websocket'.freeze

    def self.read(connection)
      parser = connection.parser

      begin
        data = connection.socket.readpartial(Connection::BUFFER_SIZE)
        parser << data
      end until parser.headers

      headers = {}
      parser.headers.each do |field, value|
        headers[Http.canonicalize_header(field)] = value
      end

      upgrade = headers[UPGRADE]
      if upgrade && upgrade.downcase == WEBSOCKET
        WebSocket.new(connection.socket, parser.http_method, parser.url, headers)
      else
        Request.new(parser.http_method, parser.url, parser.http_version, headers, connection)
      end
    end

    def initialize(method, url, version = "1.1", headers = {}, connection = nil)
      @method = method.to_s.downcase.to_sym
      raise UnsupportedArgumentError, "unknown method: #{method}" unless Http::METHODS.include? @method

      @url, @version, @headers, @connection = url, version, headers, connection
    end

    def [](header)
      @headers[header]
    end

    def uri
      @uri ||= URI(url)
    end

    def path
      uri.path
    end

    def query_string
      uri.query
    end

    def fragment
      uri.fragment
    end

    def body
      @body ||= begin
        raise "no connection given" unless @connection

        body = "" unless block_given?
        while (chunk = @connection.readpartial)
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
