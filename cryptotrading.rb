#!/usr/bin/env ruby
# Set a Crypto Trading program

require 'yaml'
require 'logger'
require 'redis'
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

CURRENCY = config['kraken']['currency']
MAXTRADE = config['kraken']['maxtrade']
MAXCONCURRENTTRADE = config['kraken']['maxconcurrenttrade']
SLEEPTIME = config['kraken']['sleeptime']
HISTORY = config['kraken']['history']

# Set Log Level
LOGLEVEL ||= Logger::DEBUG
$log = Logger.new(STDOUT)
$log.level = LOGLEVEL

$redis = Redis.new(host: config['redis']['server'], port: config['redis']['port'], db: 1)

def kraken_registerthread(maxthread)
  i=0
  while i < maxthread do
    if $redis.get("thread#{i}")
      $log.debug "thread#{i} already present in redis"
      i +=1
      next
    end
    $redis.set("thread#{i}", '{"currency":"none","status":"starting","lastcheckedvalue":0,"lastbuyvalue":0,"lastsellvalue":0}')
    $log.info "Starting thread#{i}"
    i +=1
  end  
  return 0
end

def kraken_registercurrency(currencylist)
  currencylist.each do |currency|
    if $redis.llen(currency)
      $log.info "#{currency} Already in redis"
      next
    end
    $redis.lpush(currency,'')
    $log.info "Adding Currency: #{currency}"
  end
end

def kraken_updatecurrency(currency,ticker)
  $redis.lpush(currency,ticker)
  $redis.ltrim(currency,0,HISTORY)
  $log.debug "Redis Historical data llen for #{currency} is #{$redis.llen(currency)}"
end

def kraken_analysis(currency)
  datadump = $redis.lrange(currency,0,HISTORY)
  datadump[0] = JSON.parse(datadump[0])
  datadump[HISTORY] = JSON.parse(datadump[HISTORY])
  ask_ecarttype = datadump[0]['data']['a'] - datadump[HISTORY]['data']['a']
  $log.debug ask_ecarttype
  #datadump.each do |value|
  #  value['data']['a']
  #end
end

def kraken_orderbook(pair)
  @kraken.getOrderBook(pair).each do |k,v|
    $redis.set(k,v)
    total_asks=0
    max_ask=0
    min_ask=0
    total_bids=0
    max_bid=0
    min_bid=0


    v['asks'].each {|values| 
      if values[0].to_f > max_ask.to_f 
	max_ask=values[0]
      end
      if values[0].to_f < min_ask.to_f || min_ask == 0
        min_ask=values[0] 
      end
    }
    v['asks'].each {|values| total_asks=values[0].to_f+total_asks }
    asks_average = total_asks / v['asks'].size.to_f

    v['bids'].each {|values| 
      if values[0].to_f > max_bid.to_f 
	max_bid=values[0]
      end
      if values[0].to_f < min_bid.to_f || min_bid == 0
        min_bid=values[0] 
      end
    }
    v['bids'].each {|values| total_bids=values[0].to_f+total_bids }
    bids_average = total_bids / v['asks'].size.to_f

    $log.info "Asks :"
    $log.info "\tAverage : #{asks_average}"
    $log.info "\tMax     : #{max_ask}"
    $log.info "\tMin     : #{min_ask}"
    $log.info "Bids : "
    $log.info "\tAverage : #{bids_average}"
    $log.info "\tMax     : #{max_bid}"
    $log.info "\tMin     : #{min_bid}"
  end
end

# Create Kraken instance
KRAKEN_CONFIGURATION = config['kraken']
@kraken = Kraken.new KRAKEN_CONFIGURATION

if LOGLEVEL == 0
  # dump kraken tradable pair
  @kraken.getTradableAssetPair().each do |k,v|
    $log.debug "tradable pair : #{k}"
  end
end

kraken_registercurrency(CURRENCY)
while true

  kraken_registerthread(MAXCONCURRENTTRADE)
  # Push ticker on redis for all currency to
  @kraken.getTickerInformation(CURRENCY.join(',')).each do |k,v|
	  epoch = Time.now.to_i
	  payload = { "epoch" => "#{epoch}", "data" => v.to_hash }
	  kraken_updatecurrency(k,payload.to_json)
  end

  CURRENCY.each do |value|
    if $redis.llen(value) >= HISTORY
      kraken_analysis(value)
    end
  end 

  sleep(SLEEPTIME)
end
#
#kraken_data = {}
#
#kraken_data['tickerinformation']=@kraken.getTickerInformation(config['kraken']['currency'].join(','))
#kraken_data['tickerinformation'].each do |k,v|
#  $log.info "#{k} opening price was #{v['o']}"
#  $redis.set("#{k}_OPENNING",v['o'])
#  $redis.set("#{k}_ASKARRAY",v['a'].to_json)
#  $redis.set("#{k}_BIDARRAY",v['b'])
#  $redis.set("#{k}_LASTTRADE",v['c'])
#  $redis.set("#{k}_VOLUMEARRAY",v['v'])
#  $redis.set("#{k}_VOLUMEWEIGHTEDAVERAGE",v['p'])
#  $redis.set("#{k}_NUMBEROFTRADES",v['t'])
#  $redis.set("#{k}_LOWARRAY",v['l'])
#  $redis.set("#{k}_HIGHARRAY",v['h'])
#  $log.info "#{k} ask price is #{v['a'][0]} for  #{v['a'][2]}"
#  $log.info "#{k} bad price is #{v['b'][0]} for #{v['b'][2]}"
#  $log.info "#{k} average volume weighted price is today: #{v['p'][0]} - last 24h: #{v['p'][1]}"
#  $log.info "#{k} last transaction price was #{v['c'][0]} for #{v['c'][1]}"
#  kraken_orderbook(k)
#end
#soldgain = 0
#buygain = 0
#while true
#  config['kraken']['currency'].each {|value| 
#    oldticker = JSON.parse($redis.get("#{value}_ASKARRAY"))
#    ticker = @kraken.getTickerInformation(value) 
#    $log.info "###### #{value} #####" 
#    $log.info "bid: #{ticker[value]['b'][0]}"
#    $log.info "ask: #{ticker[value]['a'][0]}"
#    $log.info "redis: #{oldticker}"
#
#    #bid_deviation = ((ticker[value]['b'][0].to_f / oldticker[0].to_f) * 100) - 100
#    #ask_deviation = ((ticker[value]['a'][0].to_f / oldticker[0].to_f) * 100) - 100
#    #$log.info "Bid Deviation (I can sell to bidder) = #{bid_deviation}"
#    #$log.info "Ask Deviation (I can buy from asker) = #{ask_deviation}"
#    #if bid_deviation > 0.5
#    #  $redis.set("selling",ticker[value]['b'][0].to_f)
#    #  soldgain = ticker[value]['b'][0].to_f - oldticker[0].to_f
#    #  $redis.set("sold",soldgain)
#    #  $log.info "sold #{soldgain}"
#    #  oldticker = ticker[value]['b'][0].to_f
#    #end
#    #if ask_deviation 
#    #  $redis.set("buying",ticker[value]['a'][0].to_f)
#    #  buygain = oldticker[0].to_f - ticker[value]['b'][0].to_f
#    #  $redis.set("bought",buygain)
#    #  $log.info "bought #{buygain}"
#    #  oldticker = ticker[value]['b'][0].to_f
#    #end
#  } 
#  sleep(60)
#end
