require 'forwardable'

class ExampleRequest
  extend Forwardable
  def_delegators :@headers, :[], :[]=
  attr_accessor  :method, :path, :version, :body

  def initialize(method = :get, path = "/", version = "1.1", headers = {}, body = nil)
    @method = method.to_s.upcase
    @path = path
    @version = "1.1"
    @headers = {
      'Host'       => 'www.example.com',
      'Connection' => 'keep-alive',
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.78 S',
      'Accept'     => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Encoding' => 'gzip,deflate,sdch',
      'Accept-Language' => 'en-US,en;q=0.8',
      'Accept-Charset'  => 'ISO-8859-1,utf-8;q=0.7,*;q=0.3'
    }.merge(headers)

    @body = body
  end

  def to_s
    if @body && !@headers['Content-Length']
      @headers['Content-Length'] = @body.length
    end

    "#{@method} #{@path} HTTP/#{@version}\r\n" <<
    @headers.map { |k, v| "#{k}: #{v}" }.join("\r\n") << "\r\n\r\n" <<
    (@body ? @body : '')
  end

  def inspect_method
    "#<Reel::Request #{@method} #{path} HTTP/#{version} @headers=#{@headers}>"
  end
end
