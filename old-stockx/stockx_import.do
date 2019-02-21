cap: cd "/Users/lstein2/Dropbox (ASU)/Sneakers/Data/StockX/stockx v9"
cap: cd "\\itfs1\yzhao87\Desktop\stockx v9"
set more off

/* *********************
*
*  sales_fromsales (from test_price)
*
*  **********************/

import delimited using "StockX_Test_Price_manualclean.csv", delimiter(",") stripquotes(yes) clear
gen isdata = 1

assert (missing(v2) & missing(v3) & missing(v4) & missing(v5) & missing(v6) & missing(v7)) if v1[_n+2] == "Date,Time,Size,Sale Price"
gen url = v1 if inlist(v1[_n+2], "Date,Time,Size,Sale Price", "#EANF#")
replace isdata = 0 if inlist(v1[_n+2], "Date,Time,Size,Sale Price", "#EANF#")

assert (missing(v2) & missing(v3) & missing(v4) & missing(v5) & missing(v6) & missing(v7)) if v1[_n+1] == "Date,Time,Size,Sale Price"
gen shoename = v1 if inlist(v1[_n+1], "Date,Time,Size,Sale Price", "#EANF#")
replace isdata = 0 if inlist(v1[_n+1], "Date,Time,Size,Sale Price", "#EANF#")

replace isdata = 0 if inlist(v1[_n], "Date,Time,Size,Sale Price", "#EANF#")
replace isdata = 0 if (missing(v1) & missing(v2) & missing(v3) & missing(v4) & missing(v5) & missing(v6) & missing(v7))


/**
FAILED ATTEMPT TO AUTOMATICALLY CLEAN SCRAPE ERRORS
Now just manually fixing csv file before import

drop last observation where the 
code has already run to the end and 
pulling "about:blank"**************

drop if v1=="about:blank"
/**************************************
drop empty data where obs missing v1 &
v2*************************************/
drop if missing(v1) & missing(v2) & missing(v3) & missing(v4) & missing(v5) & missing(v6) & missing(v7)

tabulate v1 if isdata==1
tabulate v1 if isdata==1 & (strpos(lower(v1),"http") > 0)
/***locate that failure, obs: 219850,219854,219858,219868,222344,222367,245033***/
bro if isdata==1 & (strpos(lower(v1),"http") > 0)
/***turn out some reebok shoenames are cut into 2 rows****/
/***my fix***/
replace isdata = 0 if (missing(v2) & missing(v3) & missing(v4) & missing(v5) & missing(v6) & missing(v7))
***/



assert inlist(v1, "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday") if isdata 

gen shoe = 1 in 1
replace shoe = shoe[_n-1] + ~missing(url) in 2/-1

replace url = url[_n-1] if missing(url)
replace shoename = shoename[_n-1] if missing(shoename)

keep if isdata | (v1 == "#EANF#")
drop if inlist(shoename, "#EANF#", "about:blank")
replace v1 = "" if ~isdata

assert inlist(isdata, 0, 1)
tab isdata

gen date_string = v1 + " " + v2 + ", " + string(v3) if isdata
gen long date = date(date_string, "#MDY") if isdata
format date %td
drop date_string v1 v2 v3

assert substr(v4,-3,.) == "EST" if isdata
gen double time = clock(v4, "hm##") + cofd(date) if isdata
format time %tc
drop v4

gen price_string = v6 + string(v7,"%03.0f") if ~missing(v7) & isdata
replace price_string = v6 if missing(v7) & isdata
assert ~missing(price_string) if isdata
assert substr(price_string,1,1) == "$" if isdata
destring price_string, gen(price) ignore("$")
assert ~missing(price) if isdata
drop v6 v7 price_string

rename v5 size
gen size2x = 2 * size
label var size2x "Size times two"

assert (substr(url,1,8) == "https://") | (substr(url,1,14) == "Ã¯Â»Â¿https://") | (substr(url,1,11) == "•ÈÀhttps://")
replace url = substr(url,4,.) if substr(url,1,11) == "•ÈÀhttps://"
replace url = substr(url,7,.) if substr(url,1,14) == "Ã¯Â»Â¿https://"
assert (substr(url,1,8) == "https://")

assert ~missing(shoe)
assert ~missing(url)
assert ~missing(shoename)
assert ~missing(price) if isdata
assert ~missing(size)  if isdata
assert ~missing(date)  if isdata
assert ~missing(time)  if isdata


compress
order shoe url shoename date time size size2x price isdata
save stockx_sales_fromsales, replace




/* *********************
*
*  shoes_fromsales
*
*  **********************/

use stockx_sales_fromsales, clear

collapse (first) url shoename (min) mindate=date mintime=time (max) maxdate=date maxtime=time (mean) price_mean=price (median) price_med=price (sd) price_sd=price (p75) price_p75=price (p25) price_p25=price (iqr) price_iqr=price (sum) sales=isdata, by(shoe)
assert missing(mindate) == (sales == 0)
assert missing(mintime) == (sales == 0)
assert missing(maxdate) == (sales == 0)
assert missing(maxtime) == (sales == 0)
assert missing(price_mean) == (sales == 0)
assert missing(price_med) == (sales == 0)
assert missing(price_sd) == (sales < 2)
assert missing(price_p75) == (sales == 0)
assert missing(price_p25) == (sales == 0)
assert missing(price_iqr) == (sales == 0)
assert ~missing(url)
assert ~missing(shoename)

assert (shoe == _n)

// Shoe name and URL have same level of uniqueness
bys shoename: assert url==url[1]
bys url: assert shoename==shoename[1]


// Some shoes show up multiple times
gsort +url -sales +shoe
by url: gen nonduplicate = (_n==1)
by url: gen shoe_canonical = shoe[1]
*browse if url == url[_n-1] | url == url[_n+1]

sort shoe
compress

order shoe nonduplicate shoe_canonical url shoename sales
save stockx_shoes_fromsales, replace




/* *********************
*
*  sales_fromsales (revising with duplicates information from shoes_fromsales)
*
*  **********************/

use stockx_sales_fromsales
keep if isdata
drop isdata

merge m:1 shoe using stockx_shoes_fromsales, assert(match using) keep(match) keepusing(nonduplicate shoe_canonical) nogen

//Check that all sales of duplicate shoes are actually duplicate sales
gsort shoe_canonical time size price -nonduplicate
by shoe_canonical time size price: egen nonduplicate_sales   = sum(nonduplicate)
by shoe_canonical time size price: egen total_sales = count(nonduplicate)
by shoe_canonical time size price: assert nonduplicate[1] == 1
assert (total_sales == 2 * nonduplicate_sales) if (nonduplicate == 0)
drop total_sales nonduplicate_sales

keep if nonduplicate
assert shoe == shoe_canonical
drop nonduplicate shoe_canonical

compress
save stockx_sales_fromsales, replace




/* *********************
*
*  shoes_fromshoes (from test)
*
*  **********************/
/* *********************
*
*  shoename/colorway cut into 2 part, including 7 reebok shoes, and pair #1349's colorway
*  manually corrected and reimported, got 98532 rows = 4284 pairs
*
*  **********************/

import delimited using "StockX_Test_manualclean.csv", delimiter("") stripquotes(yes) clear

forvalues i = 2/23 {
	gen v`i' = v1[_n + `i' - 1] if (mod(_n,23) == 1)
}

keep if (mod(_n,23) == 1)

assert ~(v1 == "#EANF#")

gen shoe = _n


rename v1 url
rename v2 shoename
rename v3 line
rename v4 subline
rename v5 ticker
rename v6 lowest_ask_price
rename v7 lowest_ask_size
rename v8 highest_bid_price
rename v9 highest_bid_size
rename v10 last_sale_price
rename v11 last_sale_dollarchange
rename v12 last_sale_pctchange
rename v13 last_sale_size
rename v14 style_code
rename v15 colorway
rename v16 rdate
rename v17 msrp
rename v18 w52_hi_lo
rename v19 mo12_ds_range
rename v20 volatility
rename v21 ds_sold
rename v22 price_premium
rename v23 avg_ds_price

/*format releasedate*/
gen long releasedate = date(rdate, "MDY", 2050)
format releasedate %td
summ releasedate, det f
drop rdate

/*remove special characters in url*/
assert (substr(url,1,8) == "https://") | (substr(url,1,14) == "Ã¯Â»Â¿https://") | (substr(url,1,11) == "•ÈÀhttps://")
replace url = substr(url,4,.) if substr(url,1,11) == "•ÈÀhttps://"
replace url = substr(url,7,.) if substr(url,1,14) == "Ã¯Â»Â¿https://"
assert (substr(url,1,8) == "https://")


/*strip "()" off pctmove*/
assert substr(last_sale_pctchange,1,1) == "("
assert substr(last_sale_pctchange,-1,1) == ")"
replace last_sale_pct = subinstr(last_sale_pct,"(","",.)
replace last_sale_pct = subinstr(last_sale_pct,")","",.)



/*split 2 part w52_hi-lo*/
split w52_hi_lo, p(` $')
assert ~missing(w52_hi_lo1, w52_hi_lo2)

/*split 2 part mo12_ds_range*/
split mo12_ds_range, p(` - ')
assert mo12_ds_range2 == "-"
assert ~missing(mo12_ds_range1, mo12_ds_range2, mo12_ds_range3)


drop w52_hi_lo mo12_ds_range mo12_ds_range2
rename w52_hi_lo1 w52_hi
rename w52_hi_lo2 w52_lo
rename mo12_ds_range1 mo12_ds_lo
rename mo12_ds_range3 mo12_ds_hi

/*strip "$" off multiple var*/
foreach var of varlist ds_sold msrp lowest_ask_price highest_bid_price last_sale_price w52_hi w52_lo last_sale_dollar avg_ds_price mo12_ds_hi mo12_ds_lo {
	assert ~missing(`var')
	replace `var' = "" if inlist(`var', "$--", "--", " -- --", "-- - --")
	destring `var', replace ignore("$,")
}

/*"nullify" missing percentage variables*/
foreach var of varlist volatility price_premium last_sale_pct {
	assert ~missing(`var')
	replace `var' = "" if inlist(`var', "$--", "--", " --")
	destring `var', percent replace
}


/***********************************
**sometime down the road we are going
**to pull "all bids" and "all asks"
** and "pairs available"?***********
************************************/

/*clean up lowest_ask_size and highest_bid_size*/

foreach var of varlist last_sale_size lowest_ask_size highest_bid_size {
	assert (substr(`var', 1, 6) == "Size: ") | (substr(`var', 1, 7) == "Sizes: ")
	replace `var' = substr(`var', 7, .) if (substr(`var', 1, 6) == "Size: ")
	replace `var' = substr(`var', 8, .) if (substr(`var', 1, 7) == "Sizes: ")
	replace `var' = "" if (`var' == "--")
}

assert (strpos(last_sale_size, ", ")>0 | missing(last_sale_size)) if missing(last_sale_price)

/*clean up msrp*/
replace msrp = . if msrp == 0

/*clean up ticker*/
assert ~missing(ticker)
replace ticker = "" if ticker == "N/A"

assert strpos(ticker, "-")>0 if ~missing(ticker)
gen ticker_pre = substr(ticker, 1, strpos(ticker, "-")-1) if ~missing(ticker)
gen ticker_post = substr(ticker, strpos(ticker, "-")+1, .) if ~missing(ticker)

assert ~missing(style_code)
replace style_code = "" if style_code == "N/A"


/* CLEAN LINE AND SUBLINE */

assert subline == "#EANF#" if ticker == "ADI80-BAPEUNDFTDGR"
assert subline == "#EANF#" if ticker == "ADICRZY-AWARD"
assert subline == "#EANF#" if ticker == "ADIPRO-BIGSEANRD"
assert subline == "#EANF#" if ticker == "STAN-AMRCNDAD"
assert subline == "#EANF#" if ticker == "STAN-BAIT420"
assert subline == "#EANF#" if ticker == "STAN-COLETTE"
assert subline == "#EANF#" if ticker == "STAN-PHARRELWH"
assert subline == "#EANF#" if ticker == "ADI80-UNDFTD"
assert subline == "#EANF#" if ticker == "TMAC3-PACKER"
assert subline == "#EANF#" if ticker == "AIRBO-DIAMOND"
assert subline == "#EANF#" if ticker == "AM1-THESIX"
assert subline == "#EANF#" if ticker == "SBDNKH-BAO"
assert subline == "#EANF#" if ticker == "SBDNKH-CIVILIST"
assert subline == "#EANF#" if ticker == "SBDNKL-QRTRSNK"
assert subline == "#EANF#" if ticker == "SBDNKL-CRAWFSH"
assert subline == "#EANF#" if ticker == "DART-GYMRED"
assert subline == "#EANF#" if ticker == "TIEMPO94-ALLRED"
assert subline == "#EANF#" if ticker == "TIEMPO94-SLVRBLK"

replace line = "Adidas" if ticker == "ADI80-BAPEUNDFTDGR"
replace line = "Adidas" if ticker == "ADICRZY-AWARD"
replace line = "Adidas" if ticker == "ADIPRO-BIGSEANRD"
replace line = "Adidas" if ticker == "STAN-AMRCNDAD"
replace line = "Adidas" if ticker == "STAN-BAIT420"
replace line = "Adidas" if ticker == "STAN-COLETTE"
replace line = "Adidas" if ticker == "STAN-PHARRELWH"
replace line = "Adidas" if ticker == "ADI80-UNDFTD"
replace line = "Adidas" if ticker == "TMAC3-PACKER"
replace line = "Nike Other" if ticker == "AIRBO-DIAMOND"
replace line = "Air Max" if ticker == "AM1-THESIX"
replace line = "Nike SB" if ticker == "SBDNKH-BAO"
replace line = "Nike SB" if ticker == "SBDNKH-CIVILIST"
replace line = "Nike SB" if ticker == "SBDNKL-QRTRSNK"
replace line = "Nike SB" if ticker == "SBDNKL-CRAWFSH"
replace line = "Nike Other" if ticker == "DART-GYMRED"
replace line = "Nike Other" if ticker == "TIEMPO94-ALLRED"
replace line = "Nike Other" if ticker == "TIEMPO94-SLVRBLK"

replace subline = "Other" if ticker == "ADI80-BAPEUNDFTDGR"
replace subline = "Other" if ticker == "ADICRZY-AWARD"
replace subline = "Other" if ticker == "ADIPRO-BIGSEANRD"
replace subline = "Other" if ticker == "STAN-AMRCNDAD"
replace subline = "Other" if ticker == "STAN-BAIT420"
replace subline = "Other" if ticker == "STAN-COLETTE"
replace subline = "Other" if ticker == "STAN-PHARRELWH"
replace subline = "Other" if ticker == "ADI80-UNDFTD"
replace subline = "Other" if ticker == "TMAC3-PACKER"
replace subline = "Running" if ticker == "AIRBO-DIAMOND"
replace subline = "1" if ticker == "AM1-THESIX"
replace subline = "SB Dunk High" if ticker == "SBDNKH-BAO"
replace subline = "SB Dunk High" if ticker == "SBDNKH-CIVILIST"
replace subline = "SB Dunk Low" if ticker == "SBDNKL-QRTRSNK"
replace subline = "SB Dunk Low" if ticker == "SBDNKL-CRAWFSH"
replace subline = "Running" if ticker == "DART-GYMRED"
replace subline = "Running" if ticker == "TIEMPO94-ALLRED"
replace subline = "Running" if ticker == "TIEMPO94-SLVRBLK"

// Check that we've fixed all strange lines/sublines
count if inlist(line, "#EANF#", "Running") | (subline == "#EANF#")

tab line, m

levelsof line, local(lines) missing
foreach l of local lines {
	disp "`l'"
	tab subline if line == "`l'", m
}




// Check ordering relationships
assert (lowest_ask_size ~= highest_bid_size) if (lowest_ask_price <= highest_bid_price) & ~missing(lowest_ask_price, highest_bid_price)
assert w52_hi >= w52_lo
assert mo12_ds_hi >= mo12_ds_lo if ~missing(mo12_ds_lo, mo12_ds_hi)

assert last_sale_dollarchange == 0 if missing(last_sale_price)
assert last_sale_pctchange    == 0 if missing(last_sale_price)
replace last_sale_dollarchange = . if missing(last_sale_price)
replace last_sale_pctchange    = . if missing(last_sale_price)

assert ds_sold ~= 0
replace ds_sold = 0 if missing(ds_sold)
assert missing(avg_ds_price)     == (ds_sold == 0)
assert missing(mo12_ds_hi) == (ds_sold == 0)
//assert missing(mo12_ds_lo) == (ds_sold == 0)	// Three observations are missing mo12_ds_lo despite having ds sales and high

// URLs don't necessarily match between sales and shoes data. Seems like sales data has "better" URL
rename url url_alternate

compress
order shoe url_alternate shoename colorway ticker ticker_pre ticker_post style_code line subline releasedate msrp lowest_ask_price lowest_ask_size highest_bid_price highest_bid_size last_sale_price last_sale_size last_sale_dollarchange last_sale_pctchange w52_lo w52_hi volatility ds_sold avg_ds_price price_premium mo12_ds_lo mo12_ds_hi
save stockx_shoes_fromshoes, replace




/* *********************
*
*  shoes (merging shoes_fromshoes and shoes_fromsales)
*  
*  **********************/

use stockx_shoes_fromshoes, clear
merge 1:1 shoe using stockx_shoes_fromsales, update assert(match)
drop _merge

// URLs don't necessarily match between sales and shoes data
order url, before(url_alternate)
count if url ~= url_alternate
replace url_alternate = "" if (url == url_alternate)

// Create other interesting shoe-level variables [John to-do]
// E.g., Company, Parentcompany, Jordan, Yeezy, Curry, ...


save stockx_shoes, replace








/* *********************
*
*  Adding some missing MSRPs and releasedates from Sole Collector
*
*  **********************/

// Convert Sole Collector data (only those with stylecodes) to Stata
import excel "solecollector supplements 2.xlsx", sheet("Sheet1") firstrow clear
format date %td
rename stylecode style_code
rename price msrp_solecollector
rename date  releasedate_solecollector
rename title shoename_solecollector

// Eliminate some style code scrape errors
replace style_code = "" if strlen(style_code) > 400
assert strlen(style_code) <= 20

// There are some duplicates
duplicates drop

drop if missing(style_code)
assert ~missing(shoename)

gen n = _n

collapse (first) shoename_first=shoename_solecollector (last) shoename_last=shoename_solecollector (count) sc_count_solecollector=n (max) msrp_max=msrp_solecollector releasedate_max=releasedate_solecollector (min) msrp_min=msrp_solecollector releasedate_min=releasedate_solecollector, by(style_code)

gen shoename_solecollector = shoename_first if (shoename_first==shoename_last)
gen msrp_solecollector = msrp_max if (msrp_max==msrp_min)
gen releasedate_solecollector = releasedate_max if (releasedate_max==releasedate_min)
format releasedate_solecollector %td

sort style_code
order style_code

compress
save solecollector_stylecode, replace



use stockx_shoes, clear

merge m:1 style_code using solecollector_stylecode, keep(match master)


count if missing(msrp)
count if missing(msrp) & (_merge==3)
replace msrp = msrp_solecollector if missing(msrp) & (_merge==3)

count if missing(releasedate)
count if missing(releasedate) & (_merge==3)
replace releasedate = releasedate_solecollector if missing(releasedate) & (_merge==3)

rename _merge solecollector_merge

compress
save stockx_shoes, replace



/* *********************
*
*  sales (merging sales_fromsales and shoes)
*
*  **********************/


use stockx_sales_fromsales, clear
merge m:1 shoe using stockx_shoes, update assert(using match) keep(match)
drop _merge

assert nonduplicate == 1
assert shoe == shoe_canonical

drop nonduplicate shoe_canonical

order url, before(url_alternate)

compress
save stockx_sales, replace


/* *********************
*
*  Shoes (deduplicate)
*  
*  **********************/

use stockx_shoes, clear

gsort shoe_canonical -nonduplicate

assert shoe == shoe_canonical if ~nonduplicate[_n+1]
assert sales >= sales[_n+1] if ~nonduplicate[_n+1]

// Save alternate URLs that are in duplicates
replace url_alternate = url_alternate[_n+1] if missing(url_alternate) & ~nonduplicate[_n+1]

keep if nonduplicate

isid shoe_canonical
drop nonduplicate shoe_canonical

sort shoe

save stockx_shoes, replace




/* *********************
*
*  Delete interim files
*
*  **********************/

rm stockx_sales_fromsales.dta
rm stockx_shoes_fromsales.dta
rm stockx_shoes_fromshoes.dta


