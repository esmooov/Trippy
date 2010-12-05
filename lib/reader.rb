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
require File.expand_path('./article', File.dirname(__FILE__))

CONFIG = YAML::load(File.open(File.expand_path("../../config/config.yml", __FILE__)))

ACTIVITIES = {"meat" => 480, "bathroom" => 300, "hair" => 600, "nails" => 1200, "adobe" => 1800, "compile" => 3000}

SAVE_DIR = File.expand_path("../../public/articles/#{@hash}.json",__FILE__)

FileUtils.mkdir_p SAVE_DIR unless File.exists?(SAVE_DIR)

def determine_if_list(account)
  if account.scan("/").size > 0
    #it's a list
    endpoint = "http://api.twitter.com/1/#{account.split("/")[0]}/lists/#{account.split("/")[1]}/statuses.json?per_page=30"
  else
    endpoint = "http://api.twitter.com/1/statuses/user_timeline.json?screen_name=#{account}&count=30"
  end
  LOG.info(endpoint)
  endpoint
end

def hydra_fetch(account = "longreads")
  urls = []
  hydra = Typhoeus::Hydra.new
  list = Crack::JSON.parse(RestClient.get(determine_if_list(account)))
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
      Article.new(response)
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

def length_of_journey(origin,destination,geo)
  if geo == false
    origin_lat_long = get_lat_long(CGI.escape(origin))
  else
    origin_lat_long = {"lat" => geo[0],"lng" => geo[1]}
  end
  dest_lat_long = get_lat_long(CGI.escape(destination))

  hopstop = RestClient.get("http://www.hopstop.com/ws/GetRoute?licenseKey=" +
  CONFIG['hopstop_api'] + "&city1=newyork&x1=" + origin_lat_long['lat'].to_s +
  "&y1=" + origin_lat_long['lng'].to_s + "&city2=newyork&x2=" + dest_lat_long['lat'].to_s +
  "&y2=" + dest_lat_long['lng'].to_s +
  "&day=1&time=#{Time.now.strftime("%H:%m")}&mode=s")
  hopstop = Crack::XML.parse(hopstop)
  hopstop['HopStopResponse']['RouteInfo']['TotalTime'].to_i
end

def select_articles(origin,destination,twitter_account,activity,geo)
  if activity
    LOG.info activity
    myjourney = ACTIVITIES[activity]
  elsif geo
    myjourney = length_of_journey(origin,destination,geo)
  else
    myjourney = length_of_journey(origin,destination,false)
  end
  LOG.info(myjourney)
  articles = []
  read_time = 0
  urls = hydra_fetch(@twitter_account)
  urls.each do |url|
    article = url[:request].handled_response
    LOG.info "processing #{article.title}"

    if article.wc > CONFIG['wc_threshhold'] && (article.read_time <= ((myjourney / 60) - read_time))
      LOG.info "accepting #{article.title} with read time: #{article.read_time}"
      read_time += article.read_time
      articles << article
    else
      LOG.info "rejecting #{article.title} with read time: #{article.read_time}"
    end
  end
  LOG.info "total travel time is #{myjourney / 60}"
  LOG.info "total read time for this dump is #{read_time}"
  LOG.info "total articles is #{articles.size}"

  {:articles => articles, :journey_length => (myjourney / 60)}
end

def check_job_status
  jobs = Delayed::Job.all.size
  error = Delayed::Job.all.first.last_error ? Delayed::Job.all.first.last_error.to_s.gsub(/\\n|\n|\{/,'<br/>') : nil
  if error
    Delayed::Job.all.each(&:delete)
    return error.to_s
  else
    return nil
  end
end

class ArticleJob
  def initialize(origin,destination,hash,twitter_account,activity,geo)
    @origin = origin
    @destination = destination
    @hash = hash
    @twitter_account = twitter_account
    @activity = activity
    @geo = geo
  end

  def perform
    articles = {:msg => "OK", :articles => select_articles(@origin,@destination,@twitter_account,@activity,@geo)}
    File.open(File.expand_path("../../public/articles/#{@hash}.json",__FILE__),"w+") do |f|
      f.write articles.to_json
    end
  end
end
