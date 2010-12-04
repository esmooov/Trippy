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
  origin = params[:origin]
  destination = params[:destination]
  @hash = Digest::MD5.hexdigest("#{Time.now.to_i}trippy")
  @articles = Delayed::Job.enqueue(select_articles(origin, destination, @hash))
  
  haml :index
end
