class Article
  WPM = 250

  attr_accessor :html, :title

  def initialize(response)
    @html  = Readability::Document.new(response.body).content rescue ""
    @text  = Sanitize.clean(@html) rescue ""
    @title = Nokogiri::HTML(response.body).search('title').text rescue ""
  end

  def wc
    @text.split(/ /).size
  end

  def read_time
    wc / WPM
  end
end