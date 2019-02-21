
import excel "Sole Collector Data Yr 2010-2015_Clean_1.0.xlsx", firstrow clear

gen rowid = _n
isid rowid

desc



list stylecode if strlen(stylecode) >= 20
replace stylecode = "" if strlen(stylecode) >= 20



destring day, replace

gen ym = mofd(date)
format %tm ym

gen quarter = quarter(date)
gen yq = qofd(date)
format %tq yq

gen dow = dow(date)

gen fakefiscalyear = year(dofq(yq+1))

gen goodcoverage = inrange(yq, tq(2011q4), tq(2015q3))

gen majorparent = inlist(parent, "nike", "adidas", "fila korea", "asics")
gen nikeoradidas = inlist(parent, "nike", "adidas")
gen nikecorporate = parent == "nike"
gen nikefamily = inlist(brand, "nike", "jordan", "air jordan")
gen jordanfamily = inlist(brand, "jordan", "air jordan")



gen model    = substr(stylecode,1,6)  if nikefamily & inlist(substr(stylecode,7,1), "-","–") & (strlen(stylecode) == 10)
gen submodel = substr(stylecode,8,10) if nikefamily & inlist(substr(stylecode,7,1), "-","–") & (strlen(stylecode) == 10)
destring model, replace
destring submodel, replace


rename description_raw description
drop *_raw*

order rowid date year fakefiscalyear month day quarter has_price price has_style brand parent

compress
save solecollector, replace
outsheet using solecollector.csv, comma replace




hist price if inrange(price, 1, 300) & majorparent, width(25) start(12.5) by(parent, cols(1))
hist price if inrange(price, 1, 300) & nikeoradidas, width(25) start(12.5) by(brand, cols(1))






hist price if inrange(price, 1, 300) & nikefamily, width(25) start(12.5) by(brand, cols(1))
tab brand fakefiscalyear if nikefamily & inrange(fakefiscalyear, 2012, 2015)

hist price if inrange(price, 1, 300) & nikefamily & goodcoverage, width(25) start(12.5) by(fakefiscalyear brand, cols(3))


graph box price if nikefamily & price < 400 & goodcoverage, over(fakefiscalyear)






tab parent, sort

tab brand parent if majorparent

tab brand if ~majorparent, sort



gen ym = mofd(date)
format %tm ym

gen yq = qofd(date)
format %tq yq


graph box price if majorparent & price < 400, over(yq)





graph bar (count) rowid, over(yq)





collapse (count) rowid, by(ym)
rename rowid countreleases
drop if missing(ym)

gen year  = year(date)
gen month = month(date)
gen quarter = quarter(date)

keep if inrange(ym, tm(2011m9), tm(2015m10))

gen lcountreleases = ln(countreleases)


reg lcountreleases i.year i.month








/* Nike investigation */

use solecollector, clear

keep if nikefamily
drop if missing(model)

assert ~missing(model, submodel)

bys model         : egen    modelcount = count(submodel)
bys model submodel: egen submodelcount = count(submodel)

// Rereleases by submodel
sort model submodel date
bys model submodel: gen subrr = (_n > 1)
bys model submodel: gen subr1price = price[1]
bys model submodel: gen subrrpricechange_first = price - price[1]
bys model submodel: gen subrrpricechange_last  = price - price[_n-1]
bys model submodel: gen subrrdatechange_first = date - date[1]
bys model submodel: gen subrrdatechange_last  = date - date[_n-1]


// Releases by model
sort model date
bys model: gen rr = (_n > 1)
bys model: gen r1price = price[1]
bys model: gen rrpricechange_first = price - price[1]
bys model: gen rrpricechange_last  = price - price[_n-1]
bys model: gen rrdatechange_first = date - date[1]
bys model: gen rrdatechange_last  = date - date[_n-1]


