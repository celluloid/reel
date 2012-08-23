require 'reel'
require 'octarine'

module Reel
  module App
    def self.included(base)
      base.class_eval do
        include Octarine::App

        attr_accessor :server
      end
    end

    def initialize(host, port)
      super()
      @server = Reel::Server.supervise host, port do |connection|
        if connection.request # why is this nil sometimes?
          request = connection.request
          status, headers, body = call Rack::MockRequest.env_for(request.url, :method => request.method, :input => request.body)
          connection.respond status_symbol(status), headers, body.to_s
        end
      end
    end

    def status_symbol(status)
      status.is_a?(Fixnum) ? Http::Response::STATUS_CODES[status].downcase.gsub(/\s|-/, '_').to_sym : status.to_sym
    end

    def terminate
      @server.terminate
    end
  end
end
