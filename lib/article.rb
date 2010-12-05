class Article
  WPM = 250

  attr_accessor :html, :title, :id

  def initialize(response)
    @html  = Readability::Document.new(response.body).content rescue ""
    @text  = Sanitize.clean(@html) rescue ""
    @title = Nokogiri::HTML(response.body).search('title').text rescue ""
    @id    = Digest::MD5.hexdigest(@text)
  end

  def wc
    @text.split(/ /).size
  end

  def read_time
    wc / WPM
  end

end