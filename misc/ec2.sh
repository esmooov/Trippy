#!/bin/sh

cd ~

apt-get -y update
apt-get -y install build-essential
apt-get -y install automake
apt-get -y install checkinstall

apt-get -y install ruby
apt-get -y install ruby1.8-dev
apt-get -y install libzlib-ruby
apt-get -y install libyaml-ruby
apt-get -y install libdrb-ruby
apt-get -y install liberb-ruby
apt-get -y install irb
apt-get -y install rdoc
apt-get -y install zlib1g-dev
apt-get -y install libopenssl-ruby
apt-get -y install git-core
apt-get -y install mysql-server
apt-get -y install mysql-client
apt-get -y install libmysql-ruby libmysqlclient-dev
apt-get -y install sqlite3 libsqlite3-dev libsqlite3-ruby1.8 libdbd-sqlite3-ruby1.8
apt-get -y install libssl-dev 
apt-get -y install libcurl4-openssl-dev
apt-get -y install libxslt-dev libxml2-dev
apt-get -y install zip unzip
apt-get -y update

curl -O http://production.cf.rubygems.org/rubygems/rubygems-1.3.7.tgz && \
tar xzvf rubygems-1.3.7.tgz && \
cd rubygems-1.3.7 && \
sudo ruby setup.rb
sudo ln -s /usr/bin/gem1.8 /usr/bin/gem

sudo gem update --system
sudo gem install sqlite3-ruby rails capistrano \
sinatra haml rest-client ruby-readability nokogiri daemons \
sanitize twitter-text crack curb typhoeus --no-ri --no-rdoc
sudo gem install passenger -v 3.0.0 --no-ri --no-rdoc

sudo passenger-install-nginx-module --auto --prefix=/opt/nginx --auto-download

# create the server folders
sudo mkdir -p /var/www/html/trippy
sudo mkdir -p /var/www/html/trippy/shared
sudo chown -R ubuntu /var/www/html/trippy/shared

# install nginx.conf
# which will run the server on port 80
cd /opt/nginx/conf && \
sudo curl https://gist.github.com/raw/5c8de640c887b22a9446/trippy-nginx.conf -o nginx.conf

# install nginx restarter in init.d
cd /etc/init.d && \
curl https://gist.github.com/raw/8a8a243b8afd6fe56667/nginx -o nginx
sudo chmod +x nginx

sudo /etc/init.d/nginx stop
sudo /etc/init.d/nginx start
