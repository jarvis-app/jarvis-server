require File.dirname(__FILE__) + "/app/main.rb"

# Rack middleware goes here

# production-only middleware
if ENV['RACK_ENV'].eql? :production
  use Rack::Deflater   # gzip compression
end

ACCESS_TOKEN = 'MK2YDYPALRRU73D22J4CG3CYIYOLKL2I'
Wit.init
DB = Mysql.connect '127.0.0.1', 'root', '', 'geekfest'

run Sinatra::Application
