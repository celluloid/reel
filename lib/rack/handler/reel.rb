require 'reel'

module Rack
  module Handler
    class Reel
      attr_reader :options

      # Don't mess with Rack::File
      File = ::File

      DEFAULT_OPTIONS = {
        :host    => "0.0.0.0",
        :port    => 3000,
        :quiet   => false,
        :workers => 10,
        :rackup  => "config.ru"
      }

      def self.run(app, options = {})

        handler = Reel.new(options)

        ::Reel::Logger.info "A Reel good HTTP server!"
        ::Reel::Logger.info "Listening on #{handler[:host]}:#{handler[:port]}"

        handler.start
      end

      def initialize(opts = {})
        opts  = normalize_options(opts)

        @options = DEFAULT_OPTIONS.merge(opts)

        if @options[:environment]
          ENV['RACK_ENV'] = @options[:environment].to_s
        end
      end

      def start
        Celluloid::Actor[:worker_pool] = ::Reel::RackWorker.pool(size: options[:workers], args: [self])

        Celluloid::Actor[:reel_server] = ::Reel::Server.supervise(options[:host], options[:port]) do |connection|
          request = connection.request
          next unless request && request.body

          path = Object::File.join('.', 'public', request.path)

          if File.exists?(path) && !File.directory?(path)
            File.open(path) do |f|
              response = ::Reel::Response.new(200, f)
              connection.respond response
            end
          else
            Celluloid::Actor[:worker_pool].handle(request, connection)
          end
        end

        sleep
      end

      def [](option)
        @options[option]
      end

      def rack_app
        return @options[:app] if @options[:app]

        path = @options[:rackup]

        unless File.exists?(path)
          raise ConfigurationError.new("Missing rackup file '#{path}'")
        end

        @options[:app], options = Rack::Builder.parse_file path
        @options.merge! options

        unless @options[:quiet]
          @options[:app] = Rack::CommonLogger.new(@options[:app], STDOUT)
        end

        @options[:app]
      end

      private

      # Transform the options that rails s reel passes
      def normalize_options(options)
        options.inject({}) { |h, (k,v)|  h[k.downcase] = v ; h }
        options[:rackup] = options[:config] if options[:config]
        options
      end
    end

    register :reel, Reel
  end
end