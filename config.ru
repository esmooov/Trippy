require 'rubygems'
require './trippy'

set :run, false
set :environment, :production

run Sinatra::Application