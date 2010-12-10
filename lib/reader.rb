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
SAVE_DIR = File.expand_path("../../public/articles/#{@hash}.json",__FILE__)
FileUtils.mkdir_p SAVE_DIR unless File.exists?(SAVE_DIR)

module Trippy
  class Twitter
    API_BASE = "http://api.twitter.com/1/"
    attr_reader :account

    def initialize(account)
      @account = account
    end
    
    def endpoint
      endpoint = if @account.scan("/").size > 0
        #it's a list
        API_BASE + "#{account.split("/")[0]}/lists/#{account.split("/")[1]}/statuses.json?per_page=30"
      else
        API_BASE + "statuses/user_timeline.json?screen_name=#{account}&count=30"
      end
      endpoint      
    end
    
  end
  
  class Journey
    attr_reader :origin, :destination, :activity, :journey_length
    
    # origin, destination, geo, activity
    def initialize(opts = {})
      raise RuntimeError, "you must specify origin" unless opts[:origin]
      
      @origin = opts[:geo] ? {"lat" => geo[0],"lng" => geo[1]} : lat_long(opts[:origin])
      @destination = lat_long(opts[:destination])
      @activity = opts[:activity] || nil
      @journey_length = @activity ? non_commute_journey[@activity] : query_hopstop      
   
      @articles = []
      @accepted_article_titles = []
      @read_time = 0
    end
    
    def lat_long(address)
      r = Crack::JSON.parse(RestClient.get("http://maps.googleapis.com/maps/api/geocode/json?address=#{CGI.escape(address)}&sensor=false"))
      r['results'][0]['geometry']['location']  
    end
    
    def query_hopstop
      LOG.info("querying hopstop")
      hopstop = RestClient.get("http://www.hopstop.com/ws/GetRoute?licenseKey=" +
      CONFIG['hopstop_api'] + "&city1=newyork&x1=" + @origin['lat'].to_s +
      "&y1=" + @origin['lng'].to_s + "&city2=newyork&x2=" + @destination['lat'].to_s +
      "&y2=" + @destination['lng'].to_s +
      "&day=1&time=#{Time.now.strftime("%H:%m")}&mode=s")
      hopstop = Crack::XML.parse(hopstop)
      hopstop['HopStopResponse']['RouteInfo']['TotalTime'].to_i
    end
        
    def non_commute_journey
      {"meat" => 480, "bathroom" => 300, "hair" => 600, "nails" => 1200, "adobe" => 1800, "compile" => 3000}
    end
    
    def acceptable_article?(article)
      article.wc > CONFIG['wc_threshhold']                           &&
      (article.read_time <= ((@journey_length / 60) - @read_time))   &&
      !@accepted_article_titles.include?(article.title)  #dedupe
    end
    
    def get_articles(twitter_account)
      urls = Trippy::Request.hydra_fetch(twitter_account)
      urls.each do |url|
        article = url[:request].handled_response
        LOG.info "processing #{article.title}"
        @read_time += article.read_time
        if acceptable_article?(article)
          LOG.info "accepting #{article.title} with read time: #{article.read_time}"
          @articles << article
          @accepted_article_titles << article.title
        else
          LOG.info("rejecting #{article.title}")
        end
      end
      LOG.info "total travel time is #{journey_length / 60}"
      LOG.info "total read time for this dump is #{read_time}"
      LOG.info "total articles is #{articles.size}"

      {:articles => @articles, :journey_length => (@journey_length / 60)}
    end
  end
    
  class Request
    class << self
      def hydra_fetch(account = "longreads")
        urls = []
        hydra = Typhoeus::Hydra.new
        list = Crack::JSON.parse(RestClient.get(Trippy::Twitter.new(account).endpoint))
        list.each do |tweet|
          text = tweet['text']
          tweet_urls = ::Twitter::Extractor.extract_urls(text)
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
    end
  end
end



def check_job_status
  return nil if Delayed::Job.all.empty?
  
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
    t = Trippy::Journey.new :origin => @origin, :destination => @destination, :geo => @geo, :activity => @activity
    articles = t.get_articles(@twitter_account)
    
    articles = {:msg => "OK", :articles => articles}
    File.open(File.expand_path("../../public/articles/#{@hash}.json",__FILE__),"w+") do |f|
      f.write articles.to_json
    end
  end
end
