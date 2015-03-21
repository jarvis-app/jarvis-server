require File.dirname(__FILE__) + "/app/main.rb"

# Rack middleware goes here

# production-only middleware
if ENV['RACK_ENV'].eql? :production
  use Rack::Deflater   # gzip compression
end

ACCESS_TOKEN = 'MK2YDYPALRRU73D22J4CG3CYIYOLKL2I'
Wit.init
DB = Mysql.connect '192.168.4.70', 'root', 'dagdusheth', 'geekfest'

run Sinatra::Application
