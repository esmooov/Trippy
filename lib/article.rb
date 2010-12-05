class Article
  WPM = 250

  attr_accessor :readability_html, :title, :id

  def initialize(response)
    @readability_html = Readability::Document.new(response.body).content rescue ""
    @clean_text       = Sanitize.clean(readability_html) rescue ""
    @title            = Nokogiri::HTML(response.body).search('title').text rescue ""
    @id               = Digest::MD5.hexdigest(@clean_text)
  end

  def wc
    @clean_text.split(/ /).size
  end

  def read_time
    wc / WPM
  end

end