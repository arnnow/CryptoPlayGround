require 'kraken_client'



API_KEY = 'api_key_kraken'
API_SECRET = 'api_secret_kraken'
KrakenClient.configure do |config|
      config.api_key      = API_KEY
      config.api_secret  = API_SECRET
      config.base_uri    = 'https://api.kraken.com'
      config.api_version = 0
      config.limiter     = true
      config.tier        = 2
end

client = KrakenClient.load


trades = client.private.trades_history
puts trades['count']


