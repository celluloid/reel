module RemoteConnection
  # Obtain the IP address of the remote connection
  def remote_ip
    @socket.peeraddr(false)[3]
  end
  alias_method :remote_addr, :remote_ip

  # Obtain the hostname of the remote connection
  def remote_host
    # NOTE: Celluloid::IO does not yet support non-blocking reverse DNS
    @socket.peeraddr(true)[2]
  end
end