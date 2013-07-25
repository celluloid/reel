module Reel
  class RequestInfo < Struct.new(:http_method, :url, :http_version, :headers)
  end
end
