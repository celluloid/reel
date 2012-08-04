require 'rack'

module Reel
  class ConfigurationError < RuntimeError; end

  class Configuration
    attr_reader :options

    DEFAULT_RACKUP =
    DEFAULT_OPTIONS = {
      :host    => "0.0.0.0",
      :port    => 3000,
      :quiet   => false,
      :workers => 10,
      :rackup  => "config.ru"
    }

    def initialize(argv)
      @argv = argv
      @options = DEFAULT_OPTIONS.dup

      parser.parse! @argv

      if options[:environment]
        ENV['RACK_ENV'] = options[:environment].to_s
      end

      if @argv.last =~ /\.ru/
        @options[:rackup] = @argv.shift
      end
    end

    def parser
      @parser ||= begin
        parser = OptionParser.new do |opts|
          opts.on "-p", "--port PORT",
          "Define what port TCP port to bind to (default: 3000)" do |arg|
            @options[:port] = arg.to_i

            if @options[:port] == 0
              raise ConfigurationError.new("Port number not recognized #{arg}")
            end
          end

          opts.on "-a", "--address HOST",
          "bind to HOST address (default: 0.0.0.0)" do |arg|
            @options[:host] = arg
          end

          opts.on "-q", "--quiet", "Quiet down the output" do
            @options[:quiet] = true
          end

          opts.on "-e", "--environment ENVIRONMENT",
          "The environment to run the Rack app on (default: development)" do |arg|
            @options[:environment] = arg
          end

          opts.on "-t", "--threads NUM",
          "The number of worker threads (default: 10)" do |arg|
            @options[:workers] = arg.to_i

            if @options[:workers] < 2
              raise ConfigurationError.new('You need at least two worker threads')
            end
          end

          opts.on "-r", "--rackup FILE",
          "Load Rack config from this file (default: config.ru)" do |arg|
            @options[:rackup] = arg
          end
        end

        parser.banner = "reel <options> <rackup file>"

        parser.on_tail "-h", "--help", "Show help" do
          puts parser
          exit 1
        end

        parser
      end
    end

    def [](option)
      @options[option]
    end

    def rack_app
      return @options[:app] if @options[:app]

      path = @options[:rackup] || DEFAULT_RACKUP

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
  end
end