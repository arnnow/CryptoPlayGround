require 'kraken_client'
require 'logger'
log = Logger.new("| tee order.log")
log.info "hi"

pair_value = ARGV[0]
type_value = ARGV[1]
volume_value = ARGV[2]





log.info pair_value
log.info type_value
log.info volume_value


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


opts = {
  pair: pair_value,
  type: type_value,
  ordertype: 'market',
  volume: volume_value
}



client.private.add_order(opts)

