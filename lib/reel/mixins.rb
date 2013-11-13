module Reel
  module HTTPVersionsMixin

    HTTP_VERSION_1_0     = '1.0'.freeze
    HTTP_VERSION_1_1     = '1.1'.freeze
    DEFAULT_HTTP_VERSION = HTTP_VERSION_1_1
  end

  module ConnectionMixin

    # Obtain the IP address of the remote connection
    def remote_ip
      socket.peeraddr(false)[3]
    end
    alias remote_addr remote_ip

    # Obtain the hostname of the remote connection
    def remote_host
      # NOTE: Celluloid::IO does not yet support non-blocking reverse DNS
      socket.peeraddr(true)[2]
    end

  end

  module RequestMixin

    def method
      @request_info.http_method
    end

    def headers
      @request_info.headers
    end

    def [](header)
      headers[header]
    end

    def version
      @request_info.http_version || HTTPVersionsMixin::DEFAULT_HTTP_VERSION
    end

    def url
      @request_info.url
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

  end

end
