module Reel
  class Request
    # Tracks the state of Reel requests
    class StateMachine
      include Celluloid::FSM

      def initialize(socket)
        @socket   = socket
        @hijacked = false
      end

      default_state :headers

      state :headers, :to => [:body, :hijacked, :closed]
      state :body,    :to => [:headers, :closed]

      state :hijacked do
        @hijacked = true
      end

      # FSM fails open for valid transitions
      # Set an empty array to disallow transitioning out of closed
      state :closed, :to => [] do
        @socket.close unless @hijacked || @socket.closed?
      end
    end
  end
end
