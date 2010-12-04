
require 'rubygems'
require 'sinatra'
require 'haml'
require 'logger'
LOG = Logger.new(STDOUT)

require File.expand_path("../lib/reader.rb", __FILE__)



get '/' do 
  haml :index
end

post '/articles' do
  origin = params[:origin]
  destination = params[:destination]
  @articles = select_articles(origin,destination)
  
  haml :index
end
