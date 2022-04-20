
import delimited  "/Users/taisei/Library/Mobile Documents/com~apple~CloudDocs/test_data_largervariance.csv",clear

rename male_id bank_id
rename female_id issuer_id
rename x1 xb
rename y1 xf

keep bank_id issuer_id xb xf mval

save realized_match.dta,replace

keep bank_id issuer_id
fillin bank_id issuer_id

recode _fillin (0 = 1) (1 = 0)
rename _fillin realized

save temp_complete.dta,replace

use realized_match.dta,clear
sort bank_id
keep bank_id xb
cap drop bank_id_n
bysort bank_id:gen bank_id_n = _n
keep if bank_id_n == 1
save bank_data.dta,replace

use realized_match.dta,clear

keep issuer_id xf
save issuer_data.dta,replace

use temp_complete.dta,clear
merge m:1 bank_id using bank_data.dta
drop _merge
merge m:1 issuer_id using issuer_data.dta
drop _merge
merge m:1 bank_id issuer_id using realized_match.dta
drop _merge


cap drop mval_bank_lb mval_issuer_lb
bysort bank_id : egen mval_bank_lb = min(mval)
bysort issuer_id: egen mval_issuer_lb = min(mval)
replace mval = mval_issuer_lb if realized == 0 & mval_issuer_lb>=mval_bank_lb
replace mval = mval_bank_lb if realized == 0 & mval_issuer_lb<mval_bank_lb
gen mval_lb = mval_bank_lb if mval_issuer_lb<mval_bank_lb
replace mval_lb =mval_issuer_lb if mval_issuer_lb>=mval_bank_lb

metobit mval  xb xf , ll(mval_lb)

