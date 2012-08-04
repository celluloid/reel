require 'rack/handler'
require 'reel'

module Rack
  module Handler
    module Reel
      def self.run(app, options = {})

        begin
          config = ::Reel::Configuration.new(ARGV)

          ::Reel::Logger.info "A Reel good HTTP server!"
          ::Reel::Logger.info "Listening on #{config[:host]}:#{config[:port]}"

          Celluloid::Actor[:worker_pool] = ::Reel::RackWorker.pool(size: config[:workers], args: [config])
          Celluloid::Actor[:reel_server] = ::Reel::Server.supervise(config)

          sleep
        rescue Interrupt
          Celluloid.shutdown
          puts "Shutting down!"
        end

      end
    end

    register :reel, Reel
  end
end
