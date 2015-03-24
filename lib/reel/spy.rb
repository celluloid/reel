require 'forwardable'

module Reel
  # Prints out all traffic to a Reel server. Useful for debugging
  class Spy
    extend Forwardable

    def_delegators :@socket, :closed?
    def_delegators :@socket, :addr, :peeraddr, :setsockopt, :getsockname

    def initialize(socket, logger = STDOUT)
      @socket, @logger = socket, logger
      @proto, @port, _, @ip = @socket.peeraddr
      connected
    end

    # Log a connection to this server
    def connected
      log :connect, "+++ #{@ip}:#{@port} (#{@proto}) connected\n"
    end

    # Read from the client
    def readpartial(maxlen, outbuf = "")
      data = @socket.readpartial(maxlen, outbuf)
      log :read, data
      data
    end

    # Write data to the client
    def write(string)
      log :write, string
      @socket << string
    end
    alias << write

    # Close the socket
    def close
      @socket.close
      log :close, "--- #{@ip}:#{@port} (#{@proto}) disconnected\n"
    end

    # Log the given event
    def log(type, str)
      case type
      when :connect
        @logger << Colors.green(str)
      when :close
        @logger << Colors.red(str)
      when :read
        @logger << Colors.gold(str)
      when :write
        @logger << Colors.white(str)
      else
        raise "unknown event type: #{type.inspect}"
      end
    end

    module Colors
      module_function

      def escape(n); "\033[#{n}m"; end      
      def reset; escape 0; end
      def color(n); escape "1;#{n}"; end
      def colorize(n, str); "#{color(n)}#{str}#{reset}"; end

      def green(str); colorize(32, str); end
      def red(str);   colorize(31, str); end
      def white(str); colorize(39, str); end
      def gold(str);  colorize(33, str); end
    end
  end
end
