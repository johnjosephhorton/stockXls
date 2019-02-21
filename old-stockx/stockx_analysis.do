cap: cd "/Users/lstein2/Dropbox (ASU)/Sneakers/Data/StockX/stockx v9"
cap: cd "\\itfs1\yzhao87\Desktop\stockx v9"
set more off




/* *********************
*
*  Diagnostics
*
*  **********************/

use stockx_sales, clear

// Big increase in sales coverage starting May 27-29, 2015
// (from ~3k per month to ~15k per month)
hist date, disc width(28) freq
hist date if date >= td(1jan2015), disc width(7) freq
hist date if inrange(date, td(1may2015), td(30jun2015)), disc width(1) freq


// Size distribution: 10 is mode
hist size, disc
hist size, disc width(1)



// Effect of size on price: looks U-shaped, though small-size sales concentrated in a few expensive shoes (e.g., Yeezy Boosts)
areg price ib20.size2x, absorb(shoe)

gen sizetrunc = floor(size)
areg price ib10.sizetrunc, absorb(shoe)

gen lprice = ln(price)
areg lprice ib10.sizetrunc, absorb(shoe)
areg lprice ib10.sizetrunc if inrange(size,5, 15.5), absorb(shoe)


// Number of sales observed (ever)
bys shoe: egen salescount = count(price)
egen shoe_tag = tag(shoe)
hist salescount if shoe_tag, freq width(100) start(0)


// Number of sales observed (in various windows)
egen maxdate_allsales = max(date)
format maxdate_allsales %td

bys shoe: egen    salescount_3d =  sum(inrange(date, maxdate_allsales-3,  maxdate_allsales))
bys shoe: egen    salescount_7d =  sum(inrange(date, maxdate_allsales-7,  maxdate_allsales))
bys shoe: egen    salescount_28d = sum(inrange(date, maxdate_allsales-28, maxdate_allsales))
bys shoe: egen    salescount_84d = sum(inrange(date, maxdate_allsales-84, maxdate_allsales))

hist salescount_84d if shoe_tag, freq width(50) start(0)

// Rising and falling sales over time (for ~260 shoes with >= 50 sales in last three months)
gen frac_1m_over_3m = salescount_28d / salescount_84d
hist frac_1m_over_3m if shoe_tag & salescount_84d >= 50

// Who has significant sales? (~260 shoes with >= 50 sales in last three months)
count if shoe_tag & salescount_84d >= 50
tab line if shoe_tag & salescount_84d >= 50, sort
tab subline if shoe_tag & salescount_84d >= 50, sort
gen line_subline = line + "-" + subline
tab line_subline if shoe_tag & salescount_84d >= 50, sort
hist releasedate if shoe_tag & salescount_84d >= 50, disc width(182) freq



// Look at sales in window around release
gen datediff = date - releasedate
hist datediff if inrange(datediff, -3650, +3650), disc width(182) freq start(-3640)
// Sales flatten out ~4 months after release
hist datediff if inrange(datediff, -360, +360) & (maxdate_allsales-releasedate) >= 360, disc width(30) freq start(-360)



bys shoe: egen salescount = count(price)
egen shoe_tag = tag(shoe)
hist salescount if shoe_tag, freq width(100) start(0)



bys shoe: egen iqr = iqr(price)
bys shoe: egen median = median(price)
gen iqr_over_median = iqr/median
hist iqr_over_median if shoe_tag & salescount >= 100


bys shoe: egen iqr_84d = iqr(price) if inrange(date, maxdate-84, maxdate)
bys shoe: egen median_84d = median(price) if inrange(date, maxdate-84, maxdate)
gen iqr_over_median_84d = iqr_84d/median_84d
scatter iqr_over_median_84d salescount_84d if salescount_84d >= 50, mlab(shoe) mlabsize(tiny) msymb(i) mlabpos(0)




scatter iqr median if shoe_tag & salescount >= 100, mlab(shoe) mlabpos(0) msymb(i) mlabsize(tiny)





/* *********************
*
*  Returns over time relative to release date
*
*  **********************/

use stockx_sales, clear

gen timesincerelease = date - releasedate
gen timesincerelease_sq = timesincerelease ^ 2

gen markup = (price / msrp) - 1

summ markup if (timesincerelease == 0) & (markup < 1), det

lowess markup timesincerelease if inrange(timesincerelease, -100, +100)



hist timesincerelease if inrange(timesincerelease, -56, +104), width(7)

gen highmarkup = markup > .5 & ~missing(markup)
hist timesincerelease if inrange(timesincerelease, -56, +104), width(7) by(highmarkup)




