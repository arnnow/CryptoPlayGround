#!/usr/bin/env ruby
# Set a Crypto Trading program

require 'yaml'
require 'logger'
require 'influxdb'
require 'time'
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

CURRENCY = config['kraken']['xxbtzeur']['currency']
CRASHSLEEP = config['kraken']['xxbtzeur']['crashsleep']
SLEEPTIME = config['kraken']['xxbtzeur']['sleeptime']
KRAKEN_CONFIGURATION = config['kraken']
INFLUXDBHOST = config['influxdb']['host']
INFLUXDBDATABASE = config['influxdb']['database']

# Set Log Level
LOGLEVEL ||= Logger::DEBUG
$log = Logger.new(STDOUT)
$log.level = LOGLEVEL
$stdout.sync = true

$influxdb = InfluxDB::Client.new INFLUXDBDATABASE, host: INFLUXDBHOST

# Create Kraken instance
$kraken = Kraken.new KRAKEN_CONFIGURATION

def buy(currency,amount)
end

def sell(currency,amount)
end

def movingaverage(field,serie,pointspacing,interval,timeperiod)
  $log.debug "MovingAverage: #{field},#{pointspacing},#{timeperiod},#{interval}"
  return $influxdb.query "SELECT moving_average(min(#{field}),#{pointspacing}) FROM #{serie} WHERE time > now() - #{timeperiod} GROUP BY time(#{interval})", epoch: 's'
end

def demoaction(name,currency,price,buy,sell,timestamp,quantity)

  payload = {
    "values": {
      "name": name,
      "currency": currency,
      "price": price,
      "buy": buy,
      "sell": sell,
      "timestamp": timestamp,
      "quantity": quantity,
    },
    "tags": {
      "source": "kraken",
      "mode": "demo",
    },
    "timestamp": timestamp,
  }

  $influxdb.write_point(name,payload)
  if sell == 1
    action = "sell"
  else
    action = "buy"
  end
  $log.info "#{action} passed #{Time.at(timestamp).to_datetime}"

end

$log.info "Main: Starting Poller thread pushing to influxdb #{config['influxdb']['urls']}"

worker_count = 0
while true

  begin
    ask_nearreality = movingaverage('ask_price',CURRENCY,10,'1m','24h')
    ask_farreality = movingaverage('ask_price',CURRENCY,10,'9m','24h')
    bid_nearreality = movingaverage('bid_price',CURRENCY,10,'1m','24h')
    bid_farreality = movingaverage('bid_price',CURRENCY,10,'9m','24h')

    $log.debug "ask_nearreality: #{ask_nearreality[0]['values'][0]['time'].class}"
    $log.debug "ask_farreality: #{ask_farreality[0]['values'].size}"
    $log.debug "bid_nearreality: #{bid_nearreality[0]['values'].size}"
    $log.debug "bid_farreality: #{bid_farreality[0]['values'].size}"

    countnear = 0
    countfar = 0
    state = 'secure'
    interresting_buy_position = 0

    $log.debug ask_nearreality[0]['values'].size - 1
    while countnear < ask_nearreality[0]['values'].size - 1 do
      timenear = ask_nearreality[0]['values'][countnear]['time']
      #if timenear < ask_farreality[0]['values'][countfar]['time']
      #  countnear += 1
      #  next
      #end
      while countfar < ask_farreality[0]['values'].size - 1 do
        timefar = ask_farreality[0]['values'][countfar]['time']
        #$log.debug "#{timenear} vs #{timefar}"countfar
        #$log.debug "nearnow #{timenear}"
        #$log.debug "farnow #{timefar}"
        #$log.debug "far+1 #{ask_farreality[0]['values'][countfar+1]['time']}"
        if timenear < timefar or timenear >= ask_farreality[0]['values'][countfar+1]['time']
          countfar += 1
          next 
        end
        asknearreality = ask_nearreality[0]['values'][countnear]['moving_average'].to_i
        askfarreality = ask_farreality[0]['values'][countfar]['moving_average'].to_i
        if asknearreality > askfarreality
          #$log.debug "#{asknearreality} vs #{askfarreality}"
          #$log.debug "#{countnear}: #{ask_nearreality[0]['values'][countnear]['time']}"
          if state == 'secure'
            $log.debug "Interresting position : #{interresting_buy_position}"
            $log.debug "Buy position : #{Time.at(ask_farreality[0]['values'][countfar]['time']).to_datetime}"
            if interresting_buy_position > 3
              state = 'invest'
              buy_price = ask_nearreality[0]['values'][countnear]['moving_average']
              demoaction('demo',CURRENCY,ask_nearreality[0]['values'][countnear]['moving_average'],1,0,ask_nearreality[0]['values'][countnear]['time'],1)
              ask_farreality[0]['values'].shift
            end
            interresting_buy_position += 1
            break
          end
        end

        #$log.debug "near: #{bid_nearreality[0]['values'][countnear]['moving_average'].to_i} vs far: #{bid_farreality[0]['values'][countfar]['moving_average'].to_i}"
        bidnearreality = bid_nearreality[0]['values'][countnear]['moving_average'].to_i
        bidfarreality = bid_farreality[0]['values'][countfar]['moving_average'].to_i
        if bidnearreality < bidfarreality
          #$log.debug "#{bidnearreality} vs #{bidfarreality}"
          #$log.debug "#{countnear}: #{bid_nearreality[0]['values'][countnear]['time']}"
          if state == 'invest' and bid_nearreality[0]['values'][countfar]['moving_average'] > buy_price
            interresting_buy_position = 0
            $log.debug "Sell position : #{Time.at(ask_farreality[0]['values'][countfar]['time']).to_datetime}"
            state = 'secure'
            demoaction('demo',CURRENCY,bid_nearreality[0]['values'][countnear]['moving_average'],0,1,bid_nearreality[0]['values'][countnear]['time'],1)
            bid_farreality[0]['values'].shift
            break
          end
        end
        countfar += 1
      end
      countfar = 0
      countnear += 1
    end

    if worker_count % 100 == 0
      $log.info "Run number #{worker_count}"
    end
    worker_count+=1

    exit
    sleep(SLEEPTIME)
  rescue => e
    $log.error e
    sleep(CRASHSLEEP)
    next
  end

end
