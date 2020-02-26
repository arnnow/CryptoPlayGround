

require 'kraken_client'

class Kraken

  def initialize(configuration)
    KrakenClient.configure do |config|
      config.api_key     = configuration['api_key']
      config.api_secret  = configuration['api_secret']
      config.base_uri    = configuration['base_uri']
      config.api_version = configuration['api_version']
      config.limiter     = configuration['limiter']
      config.tier        = configuration['tier']
    end
    @@client = KrakenClient.load
  end
  
  def getTimeServer()
    return @@client.public.server_time()
  end

  def getAssetInfo()
    return @@client.public.assets() 
  end
  
  def getTradableAssetPair()
    return @@client.public.asset_pairs()
  end
  
  def getTickerInformation(pair)
    return @@client.public.ticker(pair)
  end
  
  def getOHLCData(pair)
  end
  
  def getOrderBook(pair)
    return @@client.public.order_book(pair)
  end
  
  def getRecentTrades(pair,since)
    return @@client.public.trades(pair,since)
  end
  
  def getAccountBalance()
  end
  
  def getTradeBalance(aclass,asset)
  end
  
  def getOpenOrders(trades,userref)
  end
  
  def getClosedOrders(trades,userref,starttime,endtime,ofs,closetime)
  end
  
  def queryOrdersInfo(trades,userref,txid)
  end
  
  def getTradesHistory(type,trades,starttime,endtime,ofs)
  end
  
  def queryTradesInfo(txid,trades)
  end
  
  def getOpenPositions(txid,docalcs)
  end
  
  def getLedgersInfo(aclass,asset,type,starttime,endtime,ofs)
  end
  
  def queryLedgers(id)
  end
  
  def getTradeVolume(pair,free_info)
  end
  
  def addStandardOrder(pair,type,ordertype,price,price2,volume,leverage,oflags,starttm,expiretm,userref,validate)
  end
  
  def cancelOpenOrder(txid)
  end

end
