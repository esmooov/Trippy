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

ACTIVITIES = {"meat" => 480, "bathroom" => 300, "hair" => 600, "nails" => 1200, "adobe" => 1800, "compile" => 3000}

def read_time(words)
  minutes = words / 250
end

def hydra_fetch(account = "longreads")
  urls = []
  hydra = Typhoeus::Hydra.new
  LOG.info "Cracking list"
  list = Crack::JSON.parse(RestClient.get("http://api.twitter.com/1/statuses/user_timeline.json?screen_name=#{account}&count=30"))
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
      url[:readability_html] = readability_html
    end
    hydra.queue url[:request]
    LOG.info url[:location]
  end
  hydra.run
  urls
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

def select_articles(origin,destination,twitter_account,activity)
  if activity
    LOG.info activity
    myjourney = ACTIVITIES[activity]
  else
    myjourney = length_of_journey(origin,destination)
  end
  LOG.info(myjourney)
  articles = []
  cur_wc = 0
  urls = hydra_fetch(@twitter_account)
  urls.each do |url|
    article = url
    LOG.info "processing #{article[:title]}"

    if article[:wc] > CONFIG['wc_threshhold'] && (read_time(article[:wc]) <= ((myjourney / 60) - read_time(cur_wc)))
      LOG.info "accepting #{article[:title]} with read time: #{read_time(article[:wc])}"
      cur_wc += article[:wc]
      articles << {:text => article[:readability_html], :title => article[:title]}
    else
      LOG.info "rejecting #{article[:title]} with read time: #{read_time(article[:wc])}"
    end
  end
  LOG.info "total travel time is #{myjourney / 60}"
  LOG.info "total read time for this dump is #{read_time(cur_wc)}"
  LOG.info "total articles is #{articles.size}"
  
  {:articles => articles, :journey_length => (myjourney / 60)}
end

class ArticleJob 
  def initialize(origin,destination,hash,twitter_account,activity)
    @origin = origin
    @destination = destination
    @hash = hash
    @twitter_account = twitter_account
    @activity = activity
  end
  
  def perform
    articles = {:msg => "OK", :articles => select_articles(@origin,@destination,@twitter_account,@activity)}
    LOG.info "PPPP"+@activity
    File.open(File.expand_path("../../public/articles/#{@hash}.json",__FILE__),"w+") do |f|
      f.write articles.to_json
    end
  end
end
