$KCODE = "UTF8"
require 'pp'
require 'rubygems'
require 'rest_client'
require 'readability'
require 'sanitize'
require 'twitter-text'
require 'crack'
require 'curb'
require 'typhoeus'

CONFIG = YAML::load(File.open(File.expand_path("../../config/config.yml", __FILE__)))

def read_time(words)
  minutes = words / 250
end

def parse_article(url)
  begin
    html = RestClient.get(url)
    rescue RestClient::ServerBrokeConnection
      return {:wc => 0, :title => '', :clean_text => ''}
  end
  title = Nokogiri::HTML(html).search('title')
  readability_html = Readability::Document.new(html).content
  clean_text = Sanitize.clean(readability_html)
  wc = clean_text.split(/ /).size
  {:wc => wc, :title => title, :clean_text => readability_html}
end

def hydra_fetch
  urls = []
  hydra = Typhoeus::Hydra.new
  LOG.info "Cracking list"
  list = Crack::JSON.parse(RestClient.get("http://api.twitter.com/1/harrisj/lists/news-hackers/statuses.json?per_page=50"))
  LOG.info list
  list.each do |tweet|
    text = tweet['text']
    tweet_urls = Twitter::Extractor.extract_urls(text)
    tweet_urls.flatten
    urls << tweet_urls
  end
  urls = urls.flatten.uniq
  LOG.info urls
  urls.collect!{|url| {:location => url} }
  urls.each do |url|
    url[:request] = Typhoeus::Request.new(url[:location] , :follow_location => true, :timeout => 2000, :cache_timeout => 200, :user_agent => "Mozilla/5.0 (X11; U; Linux i686; en-US) AppleWebKit/534.7 (KHTML, like Gecko) Chrome/7.0.517.44 Safari/534.7")
    url[:request].on_complete do |response|
      url[:response] = response
      begin
        url[:title] = Nokogiri::HTML(response.body).search('title').text
      rescue
        url[:title] = ""
      end
      begin
        readability_html = Readability::Document.new(response.body).content
        url[:clean_text] = Sanitize.clean(readability_html)
      rescue
        url[:clean_text] = ""
      end
      url[:wc] = url[:clean_text].split(/ /).size
    end
    hydra.queue url[:request]
    LOG.info url[:location]
  end
  hydra.run
  urls
end

def get_twitter_links
  urls = []
  list = Crack::JSON.parse(RestClient.get("http://api.twitter.com/1/harrisj/lists/news-hackers/statuses.json?per_page=50"))
  list.each do |tweet|
    text = tweet['text']
    tweet_urls = Twitter::Extractor.extract_urls(text)
    tweet_urls.flatten
    urls << tweet_urls
  end
  urls = urls.flatten.uniq
  urls.each do |url|
    begin
      url = follow_redirects(url)
      rescue Curl::Err
        url = nil
    end
  end
  
  urls.flatten
end

def follow_redirects(url)
  LOG.info "processing #{url}"
  c = Curl::Easy.new(url)
  c.follow_location = true
  c.max_redirects = nil
  c.perform
  url = c.last_effective_url
end

def get_lat_long(address)
  r = Crack::JSON.parse(RestClient.get("http://maps.googleapis.com/maps/api/geocode/json?address=#{address}&sensor=false"))
  r['results'][0]['geometry']['location']  
end

def length_of_journey(origin,destination)
  origin_lat_long = get_lat_long(CGI.escape(origin))
  dest_lat_long = get_lat_long(CGI.escape(destination))
  
  hopstop = RestClient.get("http://www.hopstop.com/ws/GetRoute?licenseKey=" + 
  CONFIG['hopstop_api'] + "&city1=newyork&x1=" + origin_lat_long['lat'].to_s + 
  "&y1=" + origin_lat_long['lng'].to_s + "&city2=newyork&x2=" + dest_lat_long['lat'].to_s +
  "&y2=" + dest_lat_long['lng'].to_s +
  "&day=1&time=#{Time.now.strftime("%H:%m")}&mode=s")
  hopstop = Crack::XML.parse(hopstop)  
  hopstop['HopStopResponse']['RouteInfo']['TotalTime'].to_i
end

def select_articles(origin,destination)
  myjourney = length_of_journey(origin,destination)
  LOG.info(myjourney)
  articles = []
  cur_wc = 0
  urls = hydra_fetch
  urls.each do |url|
    article = url
    LOG.info "processing #{article[:title]}"

    if article[:wc] > CONFIG['wc_threshhold'] && (read_time(article[:wc]) <= ((myjourney / 60) - read_time(cur_wc)))
      LOG.info "accepting #{article[:title]} with read time: #{read_time(article[:wc])}"
      cur_wc += article[:wc]
      articles << {:text => article[:clean_text], :title => article[:title]}
    else
      LOG.info "rejecting #{article[:title]} with read time: #{read_time(article[:wc])}"
    end
  end
  LOG.info "total travel time is #{myjourney / 60}"
  LOG.info "total read time for this dump is #{read_time(cur_wc)}"
  LOG.info "total articles is #{articles.size}"
  
  {:articles => articles, :journey_length => myjourney}
end

class ArticleJob 
  def initialize(origin,destination,hash)
    @origin = origin
    @destination = destination
    @hash = hash
  end
  
  def perform
    articles = {:msg => "OK", :articles => select_articles(@origin,@destination)}
    
    File.open(File.expand_path("../../public/articles/#{@hash}.json",__FILE__),"w+") do |f|
      f.write articles.to_json
    end
  end
end
