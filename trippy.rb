$:.unshift *Dir[File.dirname(__FILE__) + "/vendor/*/lib"]

require 'rubygems'
require 'active_record'
require 'delayed_job'
require 'sinatra'
require 'haml'
require 'logger'
LOG = Logger.new(STDOUT)

require File.expand_path("../lib/reader.rb", __FILE__)

configure do
  config = YAML::load(File.open('config/database.yml'))
  environment = Sinatra::Application.environment.to_s
  ActiveRecord::Base.logger = Logger.new($stdout)
  ActiveRecord::Base.establish_connection(
    config[environment]
  )
end


get '/' do 
  haml :index
end

post '/articles' do
  @origin = params[:origin]
  @destination = params[:destination]
  @twitter_account = params[:twitter_account]
  @hash = Digest::MD5.hexdigest("#{Time.now.to_i}trippy")
  @activity = (params[:commute] && params[:commute] == "on" ? nil : params[:activities] )
  Delayed::Job.enqueue ArticleJob.new(@origin, @destination, @hash, @twitter_account, @activity)
  @msg = "processing"
  
  haml :index
end

get '/articles_ready/:hash' do
  content_type :json
  @hash = params[:hash]
  
  LOG.info File.expand_path("../public/articles/#{@hash}.json",__FILE__)
  
  if File.exists?(File.expand_path("../public/articles/#{@hash}.json",__FILE__))
    json = File.open(File.expand_path("../public/articles/#{@hash}.json",__FILE__),"r").read
    @articles = JSON.parse(json).to_json
  else
    @articles = {:msg => "not_ready", :articles => []}.to_json
  end
  
  @articles
end
