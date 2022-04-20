

***Data Address ****************************
global directory "/Users/taisei/Library/Mobile Documents/com~apple~CloudDocs/IBES/"
*******************************************
cd "$directory"
set more off
cap log close

**# Step 1. Data construction

/*
See the do file "Akkusetal2021_DataConst.do"
*/

use SDC_IBES_market_merged_master_19932017.dta,replace


label variable underpricing "Underpricing"
label variable logmktvalue "log(market_value)"
label variable Rank "Underwriter prestige"
label variable hoberg_undprc "Avg underpricing"
label variable informed_rolling_avg "Avg info production"
label variable aggress_rec_rate "Ratio of relative aggressive recommendation"
label variable strong_buy_rate "Ratio of strong buy recommendation"
label variable totalasset "Assets"
label variable logasset "log(Assets)"
label variable firmage "Firmage"
label variable logfirmage "log(firmage)"
label variable VentureBacked "Venture-backed"
label variable hightech "Technology company"
label variable number_ipos_lastmonth "Number of IPOs in month"
label variable averageup_lastmonth "Average underpricing in month"
label variable vwretx_15daymean "Market return (past 15days)"
label variable vwretx_15daysd "Standard deviation return"


recode hightec (1=0) (0=1)
**# Step 2. Replicate the summary table (Table 1)

estpost summarize underpricing logmktvalue Rank hoberg_undprc informed_rolling_avg aggress_rec_rate strong_buy_rate totalasset logasset logfirmage VentureBacked hightech if issueyear>=1985&issueyear<=2010
esttab using example.csv,replace

asdoc su underpricing logmktvalue Rank hoberg_undprc informed_rolling_avg totalasset logasset logfirmage VentureBacked hightech if issueyear>=1985&issueyear<=2010, stat(mean sd p50 N) replace label
/*
outreg2 using Akkus_Table1.xls if issueyear>=1985&issueyear<=2010,replace sum(log) label keep(underpricing logmktvalue Rank hoberg_undprc informed_rolling_avg aggress_rec_rate strong_buy_rate totalasset logasset logfirmage VentureBacked hightech) eqkeep(mean) ctitle(1985-2010)

su underpricing logmktvalue Rank hoberg_undprc informed_rolling_avg aggress_rec_rate strong_buy_rate totalasset logasset logfirmage VentureBacked hightech if issueyear>=1985&issueyear<=2010

outreg2 using Akkus_Table1.xls if issueyear>=1985&issueyear<=1989,append sum(log) label keep(underpricing logmktvalue Rank hoberg_undprc informed_rolling_avg aggress_rec_rate strong_buy_rate totalasset logasset logfirmage VentureBacked hightech) eqkeep(mean) ctitle(1985-1989)

outreg2 using Akkus_Table1.xls if issueyear>=1990&issueyear<=1998,append sum(log) label keep(underpricing logmktvalue Rank hoberg_undprc informed_rolling_avg aggress_rec_rate strong_buy_rate totalasset logasset logfirmage VentureBacked hightech) eqkeep(mean) ctitle(1990-1998)

outreg2 using Akkus_Table1.xls if issueyear>=1999&issueyear<=2000,append sum(log) label keep(underpricing logmktvalue Rank hoberg_undprc informed_rolling_avg aggress_rec_rate strong_buy_rate totalasset logasset logfirmage VentureBacked hightech) eqkeep(mean) ctitle(1999-2000)

outreg2 using Akkus_Table1.xls if issueyear>=2001&issueyear<=2010,append sum(log) label keep(underpricing logmktvalue Rank hoberg_undprc informed_rolling_avg aggress_rec_rate strong_buy_rate totalasset logasset logfirmage VentureBacked hightech) eqkeep(mean) ctitle(2001-2010)

outreg2 using Akkus_Table1.xls if issueyear>=1985&issueyear<=2010,append sum(log) label keep(underpricing logmktvalue Rank hoberg_undprc informed_rolling_avg aggress_rec_rate strong_buy_rate totalasset logasset logfirmage VentureBacked hightech) eqkeep(p50) ctitle(Median) dec(4)


outreg2 using Akkus_Table1.xls if issueyear>=1985&issueyear<=2010,append sum(log) label keep(underpricing logmktvalue Rank hoberg_undprc informed_rolling_avg aggress_rec_rate strong_buy_rate totalasset logasset logfirmage VentureBacked hightech) eqkeep(N) ctitle(N)
*/


cap drop logproceeds
*replace ProceedsAmtinthisMktm = subinstr(ProceedsAmtinthisMktm,"/","",.)
*destring ProceedsAmtinthisMktm,replace
*gen logproceeds2 = log(ProceedsAmtinthisMktm)
gen logproceeds = log(ProceedsAmtsumofallMkts)


**# Step 3. OLS specifications (Table 2, Column 1-3)
global dep logmktvalue
global underwriter_attributes Rank hoberg_undprc informed_rolling_avg
global issuer_attributes logfirmage VentureBacked hightech 
global IPO_markets number_ipos_lastmonth averageup_lastmonth vwretx_15daymean vwretx_15daysd



reg $dep $underwriter_attributes $issuer_attributes $IPO_markets i.issueyear i.fama_french_industry if issueyear>=1985&issueyear<=2010,robust
reg $dep $underwriter_attributes $issuer_attributes logasset $IPO_markets i.issueyear i.fama_french_industry if issueyear>=1985&issueyear<=2010,robust
reg $dep $underwriter_attributes $issuer_attributes logasset logproceeds $IPO_markets i.issueyear i.fama_french_industry if issueyear>=1985&issueyear<=2010,robust



su  $dep $underwriter_attributes $issuer_attributes if issueyear>=1985&issueyear<=2010

reg $dep $underwriter_attributes i.issueyear i.fama_french_industry,robust
reg $dep $issuer_attributes i.issueyear i.fama_french_industry,robust

**# Step 4. Tobit specifications (Table 2, Column 4-6)

*--- Preparation --- *

/*
I need construct all possible matches
*/
cap drop issuer_id
* Every issuer is suppoed to be a first-time comer
gen issuer_id = _n
global outcomes logmktvalue underpricing logproceeds
global issuer_attributes logfirmage VentureBacked logasset hightech fama_french_industry
save temp.dta,replace


keep issuer_id issueyear $issuer_attributes $outcomes $IPO_markets
save issuer_data.dta,replace

use temp.dta,clear

cap drop uw_year_n
bysort uw_id issueyear:gen uw_year_n =_n
keep if uw_year_n == 1

keep uw_id issueyear $underwriter_attributes

save uw_data.dta,replace

use temp.dta,replace

forvalues year = 1985/2007{
	use  temp.dta,clear
	keep issuer_id uw_id issueyear
	keep if issueyear == `year'
	fillin issuer_id uw_id
	replace issueyear = `year' if issueyear ==.
	save temp_`year'.dta,replace
}

forvalues year = 2009/2010{
	use  temp.dta,clear
	keep issuer_id uw_id issueyear
	keep if issueyear == `year'
	fillin issuer_id uw_id
	replace issueyear = `year' if issueyear ==.
	save temp_`year'.dta,replace
}

use temp_1985.dta,clear
forvalues year = 1986/2007{
	append using temp_`year'
}

forvalues year = 2009/2010{
	append using temp_`year'
}

recode _fillin (0 = 1) (1 = 0)
rename _fillin realized

save temp_complete.dta,replace

cap drop _merge
merge m:1 issueyear issuer_id using issuer_data.dta
keep if _merge == 3
drop _merge
merge m:1 issueyear uw_id using uw_data.dta
keep if _merge == 3
drop _merge


global issuer_attributes logfirmage
global underwriter_attributes Rank

cap drop mval_uw_lb mval_issuer_lb
bysort uw_id : egen mval_bank_lb = min(logmktvalue)
bysort issuer_id: egen mval_issuer_lb = min(logmktvalue)
replace logmktvalue = mval_issuer_lb if realized == 0 & mval_issuer_lb>=mval_bank_lb
replace logmktvalue = mval_bank_lb if realized == 0 & mval_issuer_lb<mval_bank_lb

gen logmktvalue_lb = mval_issuer_lb if  mval_issuer_lb>=mval_bank_lb
replace logmktvalue_lb = mval_bank_lb if mval_issuer_lb<mval_bank_lb



metobit logmktvalue  $issuer_attributes $underwriter_attributes  , ll(logmktvalue_lb)

metobit logmktvalue  $issuer_attributes $underwriter_attributes $IPO_markets logasset i.issueyear i.fama_french_industry , ll(logmktvalue)

metobit logmktvalue  $issuer_attributes $underwriter_attributes $IPO_markets logasset logproceeds i.issueyear i.fama_french_industry , ll(logmktvalue)



**# Step 6. Determinants of IPO Underpricing (Table 7)

**# Step 7. Extension: using analyst data
