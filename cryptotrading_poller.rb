#!/usr/bin/env ruby
# Set a Crypto Trading program

require 'yaml'
require 'logger'
require 'influxdb'
require_relative 'lib/platform/kraken'

## Load logger lib
begin
  require 'logger/colorz'
rescue LoadError
else
  Logger::Colors.send(:remove_const,:SCHEMA)
  Logger::Colors::SCHEMA = {
    STDOUT => %w[light_blue green brown red purple cyan],
    STDERR => %w[light_blue green yellow light_red light_purple light_cyan],
 }
end


#Load config File
config = YAML.load_file('config.yml')

CURRENCY = config['kraken']['poller']['currency']
CRASHSLEEP = config['kraken']['poller']['crashsleep']
SLEEPTIME = config['kraken']['poller']['sleeptime']
HISTORY = config['kraken']['history']
KRAKEN_CONFIGURATION = config['kraken']
INFLUXDBHOST = config['influxdb']['host']
INFLUXDBDATABASE = config['influxdb']['database']

# Set Log Level
LOGLEVEL ||= Logger::INFO
$log = Logger.new(STDOUT)
$log.level = LOGLEVEL
$stdout.sync = true

$influxdb = InfluxDB::Client.new INFLUXDBDATABASE, host: INFLUXDBHOST

# Create Kraken instance
$kraken = Kraken.new KRAKEN_CONFIGURATION

def updatecurrency(payload,currency)
  $log.debug "UpdateInflux: Before #{payload}"
  $influxdb.write_point(currency,payload)
  $log.debug "UpdateInflux: pushed #{payload}"
end


$log.info "Main: Starting Poller thread pushing to influxdb #{config['influxdb']['urls']}"

worker_count = 0
while true

  begin
    # Push ticker on redis for all currency defined in config file
    $kraken.getTickerInformation(CURRENCY.join(',')).each do |k,v|
      epoch = Time.now.to_i
      ticker = v.to_hash

      ask_price = ticker['a'][0].to_f
      ask_whole_lot_volume = ticker['a'][1].to_f
      ask_lot_volume = ticker['a'][2].to_f
      bid_price = ticker['b'][0].to_f
      bid_whole_lot_volume = ticker['b'][1].to_f
      bid_lot_volume = ticker['b'][2].to_f
      last_trade_closed_price = ticker['c'][0].to_f
      last_trade_closed_lot_volume = ticker['c'][1].to_f
      volume_today = ticker['v'][0].to_f
      volume_last24h = ticker['v'][1].to_f
      volume_weighted_average_price_today = ticker['p'][0].to_f
      volume_weighted_average_price_last24h = ticker['p'][1].to_f
      number_of_trades_today = ticker['t'][0].to_f
      number_of_trades_last24h = ticker['t'][1].to_f
      low_today = ticker['l'][0].to_f
      low_last24h = ticker['l'][1].to_f
      high_today = ticker['h'][0].to_f
      high_last24h = ticker['h'][1].to_f
      opening_price = ticker['o'].to_f

      payload = {
        "values":  { 
          "epoch":                                 epoch, 
          "pairname":                              k,
          "ask_price":                             ask_price,
          "ask_whole_lot_volume":                  ask_whole_lot_volume,
          "ask_lot_volume":                        ask_lot_volume,
          "bid_price":                             bid_price,
          "bid_whole_lot_volume":                  bid_whole_lot_volume,
          "bid_lot_volume":                        bid_lot_volume,
          "last_trade_closed_price":               last_trade_closed_price,
          "last_trade_closed_lot_volume":          last_trade_closed_lot_volume,
          "volume_today":                          volume_today,
          "volume_last24h":                        volume_last24h,
          "volume_weighted_average_price_today":   volume_weighted_average_price_today,
          "volume_weighted_average_price_last24h": volume_weighted_average_price_last24h,
          "number_of_trades_today":                number_of_trades_today,
          "number_of_trades_last24h":              number_of_trades_last24h,
          "low_today":                             low_today,
          "low_last24h":                           low_last24h,
          "high_today":                            high_today,
          "high_last24h":                          high_last24h,
          "opening_price":                         opening_price,
        },
        "tags": {
          "source": "kraken"
        },
      }
      updatecurrency(payload,k)
    end

    if worker_count % 100 == 0
      $log.info "Run number #{worker_count}"
    end
    worker_count+=1

    sleep(SLEEPTIME)
  rescue => e
    $log.error e
    sleep(CRASHSLEEP)
    next
  end



end
