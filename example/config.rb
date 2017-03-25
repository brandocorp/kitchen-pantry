require 'kitchen/pantry'

chef_server_url "http://#{Kitchen::Pantry.local_ipaddress}:12358"
client_key ".chef/pantry.pem"
node_name "pantry"
