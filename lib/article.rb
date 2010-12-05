class Article
  WPM = 250

  attr_accessor :readability_html, :title

  def initialize(response)
    @readability_html = Readability::Document.new(response.body).content rescue ""
    @clean_text       = Sanitize.clean(readability_html) rescue ""
    @title            = Nokogiri::HTML(response.body).search('title').text rescue ""
  end

  def wc
    clean_text.split(/ /).size
  end

  def read_time
    wc / WPM
  end

end