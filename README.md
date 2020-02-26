### Some playing around with CryptoCurrency Redis & InfluxDB

# Fichier de configuration
Seuil max d'action (5€)  
Nombre max d'action en cour - argent placée - 10 (10*5€=50€)  
URL API  
KEY API  
sell_percent_seuil - seuil en % de gain pour vendre  
Tableau des currency a jouer  
numberofthreadpercurrency  
dry-run variable (true for dry-run)  
dry-run file (to detect and switch to dry-run automatically)  
stop file (automatically stop all transaction and switch to sleep state)  

# Librairie plateform:
Librairie pour kraken, ce qui donne la possiblité d'avoir une lib pour d'autre plateforme  

Get tendance (durée, currency)  
Get Average (currency)  
Get price (date, currency)  
Buy (montant, currency)  
Sell (montant, currency)  
GetOrderHistory()  
Get AccountInfo(account) -> get all info and where they are placeda  



### Code principal:

load libs  
load needed geam  
load logger  

Configuration of the program
----------------------------
Recuperer les variables du fichier de configuration  
Set the ration of invest per currency per thread: if no ratio is set then, number of thread - already set / number of currencya  
ex : 10(thread) - 4 on bitcoin / 5 currency = 1(this is the modulo)  

functions:
---------
Set montant total a investir  
	store nombre de thread * seuil -> 5*10=50#  
	in redis invest:total:50€  
	getAccountBalance  
Set thread(threadid,state,currency,value,lastbuyvalue:lastsellvalue)  
	Enregistrement dans redis  
	thread1:currency:waiting|active:value:lastbuyvalue:lastsellvalue  
	thread2:currency:waiting|active:value:lastbuyvalue:lastsellvalue  
	thread3:currency:waiting|active:value:lastbuyvalue:lastsellvalue  

Get du montant total disponnible en € sur la plateforme  
	Store dans redis - platforme:totaleuro  
Get du montant total en cryptocurrency sur la plateforme  
	for each currency  
	Store dans redis - platform:currency:montant  

Get la valeur actuel des Monnaie  
	Store dans redis - platform:currency:value  
Get la tendance sur les 2/6/12/24/48/72h derniere heures des Monnaie  
	Store dans redis - platform:currency:lastXh:tendance  

Sell(currency,value)  
	Vendre la valeur sur la currency  

Buy(currency,value)  
	Acheter la valeur sur la currency  
	Limit to max sum allowed(5€)  


IntelligentSell(thread,seuil,currency)  
	get currency average  
	get currency current value  
	get thread last value when bought  
	Calculate possible gain or loss : (100 * (current_price/buy_priceORseuil)) - 100  
	if selling give a sallpercentseuil gain then sell or simulate if dry-run   
		store value with thread in redis  
		success : change thread state to waiting  
		log action  
		exit  
	

IntelligentBuy(thread,seuil,currency)
	get currency average
	get currency current value
	get thread last value when sold
	if tendancy is going up for 24h buy or simulate if dry-run	
		store value with thread in redis
		success : change thread state to Active
		log action 
		



Main:
-----
set du montant total a investir

6/get total currency invested and set thread accordingly
set remaining thread in waiting state

if number of thread * seuil > total to invest config then disable waiting thread

loop:
1/set sleep state if stop file detected

2/set dry-run based on conf or file detected. Switch to dry-run if file is detected

3/get tendancy

5/loop on threads value to analyse for waiting or action

6.1/ if waiting
	test number of thread/currency
	Compare and sort all tendancy for all currency - the one with the best tendancy is invested in if thread already at max then
fallback on second best and again if full...
	call fund available
		if > seuil then go
			call IntelligentBuy(thread,seuil)
		else log not enough fund
5.2/ if active
	call IntelligentSell(thread,seuil)

