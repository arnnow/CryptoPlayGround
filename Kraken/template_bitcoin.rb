require 'net/http'
require 'uri'
require 'json'
require 'logger'
require 'mail'
require 'kraken_client'
# Vestion 3.1

options = { :address              => "smtp.gmail.com",
            :port                 => 587,
            :domain               => 'your.host.name',
            :user_name            => 'usergmail',
            :password             => 'passwdgmail',
            :authentication       => 'plain',
            :enable_starttls_auto => true  }



Mail.defaults do
  delivery_method :smtp, options
end

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


# all devise are concatenate with "EUR", so if pair is "XXBTXZEUR", set "device" at "XXBTCZ", or if pair is just ETCEUR, set "devise" at "ETC"
devise = 'XXBTZ'


#Pair = Monnaie + Devise Utilisée pour échanger
pair_to_trade = "#{devise}EUR"

# set the price of your last purchase
dernier_achat = 6630
#or uncomment this lines if is the first time you run it and you don't have buy something
#dernier_achat = `ruby getPrice.rb #{pair_to_trade}`
#while dernier_achat == nil || dernier_achat == ""
#        dernier_achat = `ruby getPrice.rb #{pair_to_trade}`
#        sleep(4)
#end
#dernier_achat = dernier_achat.to_f
#until here


#montant de la transaction  en €
price_to_trade = 50
# if you have already buy a volume, put them here
volume_to_sell = 0
# percentage which seems interessting
prct_int = 5


# initial setting
volume_to_trade = (price_to_trade / dernier_achat)
derniere_vente = dernier_achat
prix_precedent = dernier_achat
seuil_max = dernier_achat
seuil_min = dernier_achat


# Very important ! You want start by a buy or a sell ? (achat/vente)
action = 'achat'




log = Logger.new("| tee #{devise}-v3.1.log")



# get current price
price = `ruby getPrice.rb #{pair_to_trade}`
while price == nil || price == ""
        price = `ruby getPrice.rb #{pair_to_trade}`
        sleep(4)
end
price = price.to_f


while true
	
	while action == 'achat'
		log.info "action : #{action}"
		# get average price (since 24H)
		price_average = `ruby getAverage.rb #{pair_to_trade}`
		while price_average == nil
		        price_average = `ruby getAverage.rb #{pair_to_trade}`
		        log.warn price_average
		        sleep(4)
		end
		price_average = price_average.to_f
		prix_precedent = price
		# get current price
		price = `ruby getPrice.rb #{pair_to_trade}`
		while price == nil || price == ""
      		  price = `ruby getPrice.rb #{pair_to_trade}`
        	  sleep(4)
		end
		price = price.to_f
		log.info price
		log.info "prix courant (hors zone) #{price}"
		# calculation percentage since last buy, sell, and 24h average
		prct_depuis_dernier_achat = ( 100 * (price / dernier_achat)) - 100
		prct_depuis_derniere_vente = 100 - ( 100 * (price/derniere_vente))
		prct_depuis_average = 100 - ( 100 * (price/price_average)) 
		log.info "prct_depuis_dernier_achat : #{prct_depuis_dernier_achat}"
		log.info "prct_depuis_derniere_vente: #{prct_depuis_derniere_vente}"
		log.info "prct_depuis_average < 2 && prct_depuis_average > -2  :#{prct_depuis_average}"


		if prct_depuis_derniere_vente > prct_int || (price < price_average * 0.9)
			if prct_depuis_derniere_vente > prct_int
				log.info "---------------------------------------------------------------"
				log.info "On entre dans une phase price > #{prct_int} depuis la derniere vente"
			end
			if (prct_depuis_average < 2 && prct_depuis_average > -2 )
				log.info "(prct_depuis_average < 2 && prct_depuis_average > -2 ) ok"
			end
			prix_min = price

			while price < ( prix_min + 0.005 * prix_min )
				price = `ruby getPrice.rb #{pair_to_trade}`
				while price == nil || price == ""
        				price = `ruby getPrice.rb #{pair_to_trade}`
        				sleep(4)
				end
				price = price.to_f
				log.info price
				log.info "prix dans la boucle intéressante de l'achat : #{price}"
				if price < prix_min
					prix_min = price
					log.info "on update le prix min à #{price}"
				end

				log.warn "achat"
				log.info "On refait un tour de boucle avec prix_min = #{prix_min} et prix : #{price}"
				log.info "pour rappel la condition est : while price < ( prix_min + 0.005 * prix_min )"
				sleep(120)
			end
			# On achète c'est assez bas et ça remonte un peu
			volume_to_trade = price_to_trade / price
			pair = pair_to_trade
			type = "buy"
			volume = volume_to_trade
			volume = volume.to_f
			volume_to_sell = volume
			count = `ruby checkOrders.rb`
			old_count = count
			log.warn "volume ---------------------------------------------- #{volume}"
			while old_count >= count

                                transaction = `ruby passOrder.rb #{pair} #{type} #{volume} `
                                sleep(10)
				count = `ruby checkOrders.rb`
                                sleep(10)
                                log.info "le old_count est à #{old_count}, et le nouveau count est à : #{count}"
                                sleep(15)
                        end
			action = 'vente'
			log.info "#{devise} Fin du game, on avait vendu #{derniere_vente}, et on achète prix : #{price}"
			dernier_achat = price
			euros_to_trade = (volume_to_trade * price)
			Mail.deliver do
			       to 'dest'
			     from 'sender'
			  subject "#{devise} - Achat automatique"
			     body "#{devise} - Fin du game, on avait vendu #{derniere_vente}, et on achète #{euros_to_trade} euros au prix de prix : #{price}"
			end
			sleep(60)
		end
	sleep(60)
	end
	while action == 'vente'
		log.info "action : #{action}"
		# On vent
		price = `ruby getPrice.rb #{pair_to_trade}`
		while price == nil || price == ""
		        price = `ruby getPrice.rb #{pair_to_trade}`
		        sleep(4)
		end
		price = price.to_f
		log.info price
		log.info "prix courant (hors zone) #{price}"
		price = price.to_f
		prct_depuis_dernier_achat = ( 100 * (price / dernier_achat)) - 100
		prct_depuis_derniere_vente =  100 -( 100 * (price/derniere_vente))

		log.info "prct_depuis_dernier_achat : #{prct_depuis_dernier_achat}"
		log.info "prct_depuis_derniere_vente: #{prct_depuis_derniere_vente}"

		if prct_depuis_dernier_achat > prct_int
			prix_max = price
			log.info "-----------------------------------------------------------------------"
			log.info "On entre dans une phase price > #{prct_int} depuis le dernier prix d'achat"
			while price > ( prix_max - 0.005 * prix_max )
				price = `ruby getPrice.rb #{pair_to_trade}`
				while price == nil || price == ""
				        price = `ruby getPrice.rb #{pair_to_trade}`
				        sleep(4)
				end
				price = price.to_f
				log.info price
				if price > prix_max
					log.info "on update le prix max à #{price}"
					prix_max = price
				end
				log.warn "vente"
				log.info "petit point dans la boucle, la condition est price > ( prix_max - 0.005 * prix_max ), et les valeurs sont price : #{price}, prix_max : #{prix_max}"
				sleep(120)
			end
			# On vend c'est assez haut et ça baisse un peu
			pair = pair_to_trade
                        type = "sell"
                        volume = volume_to_sell
			volume = volume.to_f
			count = `ruby checkOrders.rb`
                        old_count = count
                        while old_count >= count

                                transaction = `ruby passOrder.rb #{pair} #{type} #{volume} `
				sleep(15)
                                count = `ruby checkOrders.rb`
                                log.info "le old_count est à #{old_count}, et le nouveau count est à : #{count}"
                                sleep(15)
                        end
			action = 'achat'
			log.info "#{devise} - Fin du game, on avait acheté #{dernier_achat}, et on vent prix : #{price}"
			seuil_max = price
			seuil_min = price
			derniere_vente = price
			prct_depuis_dernier_achat = ( 100 * (price / dernier_achat)) - 100
			euros_to_trade = (volume_to_trade * price)
			benefice = (euros_to_trade * prct_depuis_dernier_achat ) / 100
			Mail.deliver do
			       to 'dest'
			       from 'send'
			       subject "#{devise} - Vente automatique !"
			       body "#{devise} - Fin du game, on avait acheté #{dernier_achat}, et on vent prix : #{price}i, le % depuis dernier achat est à : #{prct_depuis_dernier_achat} , et le benefice net pour #{euros_to_trade} euros est  : #{benefice} euros \n"
			end
			sleep(60)
		end
		sleep(60)
	end
	sleep (60)
end
