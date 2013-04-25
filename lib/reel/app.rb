require 'reel'
require 'octarine'

module Reel
  # Define Reel endpoints using a sinatra-like dsl (provided by octarine)
  module App
    def self.included(base)
      base.class_eval do
        include Octarine::App

        attr_accessor :server
      end
    end

    def initialize(host, port)
      super()
      @server = Reel::Server.supervise(host, port) do |connection|
        while request = connection.request
          status, headers, body = call Rack::MockRequest.env_for(request.url, :method => request.method, :input => request.body)
          response_klass = body.is_a?(Stream) ? StreamResponse : Response
          connection.respond(response_klass.new(status_symbol(status), headers, body))
        end
      end
    end

    def status_symbol(status)
      status.is_a?(Fixnum) ? Http::Response::STATUS_CODES[status].downcase.gsub(/\s|-/, '_').to_sym : status.to_sym
    end

    def terminate
      @server.terminate if @server
    end
  end
end
