#!/usr/bin/env ruby

#*       *       *       *       *       root    cd /var/www/html/trippy/shared && ruby dj_restarter
def get_process
  process = `ps ax | grep delayed_job`.split("\n").select {|q| q if q.match(/delayed_job/) }.reject {|q| q if q.match(/grep/) }
  
  if process.empty?
    `cd /var/www/html/trippy/current && sudo ENV=production script/delayed_job start`
  end
end

get_process