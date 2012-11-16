module URIParts
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