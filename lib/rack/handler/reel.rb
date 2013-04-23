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
        :pidfile => nil,
        :rackup  => "config.ru",
        :slogan  => true
      }

      def self.run(app, options = {})

        @handler = Reel.new(options.merge :app => app)
        
        yield @handler if block_given?
        @handler.start
      end
      
      def cli_announcement
        ::Reel::Logger.info ( @options[:slogan] ) ? "A Reel good HTTP server!" : "Reel: #{::Reel::VERSION} "
        ::Reel::Logger.info "Listening on #{@options[:host]}:#{@options[:port]}"
        ::Reel::Logger.info "Number of workers: #{@options[:workers]}"
        ::Reel::Logger.info "Process ID saved to: #{@options[:pidfile]}" if @options[:pidfile]
        ::Reel::Logger.info "Process ID: #{Process.pid}"
      end

      def initialize(opts = {})
        opts  = normalize_options(opts)

        @options = DEFAULT_OPTIONS.merge(opts)

        if @options[:environment]
          ENV['RACK_ENV'] = @options[:environment].to_s
        end
      end

      def start
        
        cli_announcement
        Celluloid::Actor[:reel_rack_pool] = ::Reel::RackWorker.pool(size: options[:workers], args: [self])

        ::Reel::Server.supervise_as(:reel_server, options[:host], options[:port]) do |connection|
          Celluloid::Actor[:reel_rack_pool].handle(connection.detach)
        end
        
        if pidfile = @options[:pidfile]
          File.open(pidfile, "w") { |f|
            f.puts Process.pid
          }
        end

        sleep
      end

      def stop
        Celluloid::Actor[:reel_server].terminate!
        Celluloid::Actor[:reel_rack_pool].terminate!
        exit
      end

      def [](option)
        @options[option]
      end

      def rack_app
        return @options[:app] if @options[:app]

        path = @options[:rackup]

        unless File.exists?(path)
          raise "Missing rackup file '#{path}'"
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
        options = options.inject({}) { |h, (k,v)| h[k.downcase] = v ; h }
        options[:rackup] = options[:config] if options[:config]
        options[:port] = options[:port].to_i if options[:port]
        options
      end
    end

    register :reel, Reel
  end
end
