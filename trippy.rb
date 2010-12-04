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
  @hash = Digest::MD5.hexdigest("#{Time.now.to_i}trippy")
  Delayed::Job.enqueue ArticleJob.new(@origin, @destination, @hash)
  @msg = "processing"
  
  haml :index
end

get '/articles_ready/:hash' do
  content_type :json
  
  if File.exists?(File.expand_path("../public/articles/#{@hash}.json",__FILE__))
    @articles = File.open(File.expand_path("../public/articles/#{@hash}.json",__FILE__)).read
  else
    @articles = {:stat => "not_ready"}.to_json
  end
  
  @articles
end
