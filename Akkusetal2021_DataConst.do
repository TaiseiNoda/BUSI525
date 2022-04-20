***Data/file Address ****************************
global localdataaddress "/Volumes/LaCie/IBES/"
global directory "/Users/taisei/Library/Mobile Documents/com~apple~CloudDocs/IBES/"
*******************************************
cd "$localdataaddress"
set more off
cap log close
log using 20220414_Replicating_Akkus.log,append

**# Step 1. Constructing Data

* Step 1-1. Importing SDC data

global filename Akkus_19802017
import excel ${filename}_1.xlsx,clear
drop if _n==1
export excel temp_excel.xlsx,replace
import excel temp_excel.xlsx,firstrow clear

cap drop obs_count
gen obs_count = _n
save ${filename}_1.dta,replace

import excel ${filename}_2.xlsx,clear
drop if _n==1
export excel temp_excel.xlsx,replace
import excel temp_excel.xlsx,firstrow clear

cap drop obs_count
gen obs_count = _n
drop IssueDate
save ${filename}_2.dta,replace

import excel ${filename}_3.xlsx,clear
drop if _n==1
export excel temp_excel.xlsx,replace
import excel temp_excel.xlsx,firstrow clear

cap drop obs_count
gen obs_count = _n
drop IssueDate
save ${filename}_3.dta,replace



use ${filename}_1.dta,replace
merge 1:1 obs_count  using ${filename}_2
drop _merge
merge  1:1 obs_count using ${filename}_3
drop _merge



foreach var of varlist _all{
cap drop nn`var'
cap gen byte nn`var' = real(`var')==.
}

li MainSICCode if nnMainSICCode == 1
replace MainSICCode = subinstr(MainSICCode,"A","0",.)
replace MainSICCode = subinstr(MainSICCode,"B","0",.)
li MainSICCode if nnMainSICCode == 1

cap drop hightech
gen hightech = (HighTechIndustry=="Primary Business not Hi-Tech") if HighTechIndustry!=""
tab hightech
destring ,replace

cap drop issuedate
gen issuedate = date(IssueDate,"YMD")
format issuedate %td
drop IssueDate
move issuedate Issuer


cap drop issueyear
gen issueyear = year(issuedate)


foreach var of varlist UnderwritingFee UnderwritingFeeasofPrncpl{
	replace `var' = "" if `var' == "Comb." 
	replace `var' = "" if `var' == "Comp." 	
	destring `var',replace
}

replace VentureBacked = "1" if VentureBacked=="Yes"
replace VentureBacked = "0" if VentureBacked=="No"

cap drop typeofsecutiry
encode TypeofSecurity,gen(typeofsecurity)
tab typeofsecurity
cap drop commonshare
gen commonshare = (typeofsecurity==9) if typeofsecurity!=.
*display "****Seems a little bit more than Akkus*****"
destring _all,replace

drop nn*
drop HighTechIndustry TypeofSecurity
rename TickerSymbol Ticker


drop if CUSIP ==""

cap drop CUSIP_n
bysort CUSIP: gen CUSIP_n = _n
keep if CUSIP_n == 1


save "${directory}SDC_${filename}.dta",replace

tab issueyear,matcell(freq) matrow(names)
putexcel set "${directory}SDC_198002017_IPOcount.xlsx", sheet(example1) replace
putexcel A1=("Year") A2=("Num. IPO") A3=("Percent")
putexcel A2=matrix(names) B2=matrix(freq) C3=matrix(freq/r(N))

* Step 1-2. Importing Jay Ritter's data
import excel JayRitterIPOage.xlsx,clear firstrow
cap drop CUSIP_new
gen CUSIP_new = substr(CUSIP,1,6)
rename CUSIP CUSIP8
rename CUSIP_new CUSIP
drop L M
cap drop issuedate issueyear
gen issuedate = date(OfferDate,"YMD")
gen issueyear = year(issuedate)
format issuedate %td
move issuedate CUSIP8
move CUSIP CUSIP8
drop OfferDate

keep if issueyear>=1980 & issueyear<=2017
replace Founding = . if Founding == -99
cap drop logfirmage firmage
gen firmage = issueyear - Founding
gen logfirmage = log(firmage)

destring _all,replace


keep if CUSIP!=""
cap drop temp_count
bysort CUSIP: gen temp_count =_n
keep if temp_count == 1
/*
cap drop Ticker_JR
gen Ticker_JR = Ticker
*/
merge 1:1 CUSIP using ${filename}_merged_CUSIP.dta


keep if _merge == 3
cap drop _merge


tab RANK_NO_LEADS

* 88 percent has solo lead
* Let me focus on the deals with a single lead manager for now

keep if RANK_NO_LEADS == 1

replace LeadManagersLongName = "CS First Boston Corp" if LeadManagersLongName == "CS First Boston Limited"
replace LeadManagersLongName = "Credit Suisse First Boston" if strpos(LeadManagersLongName,"Credit Suisse First Boston")

replace LeadManagersLongName = "First Albany Corporation" if strpos(LeadManagersLongName,"First Albany Capital Inc")



* Drop seems mulple lead managers
** drop if LeadManagersLongName == "Foster & Marshall/American Express Inc."

drop if LeadManagersLongName =="Prudential-Bache Securities (UK) Inc"

replace LeadManagersLongName = "Janney Montgomery Scott Inc" if strpos(LeadManagersLongName,"Janney Montgomery Scott")

replace LeadManagersLongName = "Oppenheimer & Co Inc" if strpos(LeadManagersLongName,"Oppenheimer & Co Inc (DO NOT USE after 9/2/2003)")

replace LeadManagersLongName = "Shearson Lehman Hutton Inc." if strpos(LeadManagersLongName,"Shearson Lehman Hutton")

replace LeadManagersLongName = "Donaldson Lufkin & Jenrette Inc" if strpos(LeadManagersLongName,"Donaldson Lufkin & Jenrette ")

cap drop manager_name_id
cap drop splitmanagername*
split LeadManagersLongName,gen(splitmanagername)

replace splitmanagername1 = subinstr(splitmanagername1," ","",.)

gen manager_name_id = splitmanagername1+ splitmanagername2
replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if LeadManagersLongName=="Bear Stearns International Ltd"
replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3+splitmanagername4 if LeadManagersLongName=="Credit Suisse First Boston"
replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if LeadManagersLongName=="D. H. Blair & Company, Inc."
replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if LeadManagersLongName=="D. H. Blair Investment Banking Corp."

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if LeadManagersLongName=="Dean Witter Capital Markets"

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3+ splitmanagername4+splitmanagername5  if strpos(LeadManagersLongName,"Friedman Billings Ramsey ")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if strpos(LeadManagersLongName,"Furman")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if strpos(LeadManagersLongName,"Foster")

replace manager_name_id = "Foster&Marshall/Am" if strpos(LeadManagersLongName,"Foster & Marshall/American Express")




replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3+splitmanagername4 if strpos(LeadManagersLongName,"Goldman Sachs")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3+splitmanagername4 if strpos(LeadManagersLongName,"Hanifen")

replace manager_name_id = "JPMorgan" if LeadManagersLongName == "JP Morgan & Co Inc"

replace manager_name_id = "JPMorganSecurities" if LeadManagersLongName == "JP Morgan Securities Inc"

replace manager_name_id = "LeggMasonWoodWalker" if LeadManagersLongName == "Legg Mason Wood Walker Inc"

replace manager_name_id = "LehmanBrothersKuhnLoeb" if LeadManagersLongName == "Lehman Brothers Kuhn Loeb Incorporated"

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3+splitmanagername4 if strpos(LeadManagersLongName,"Merrill Lynch")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3+splitmanagername4 if strpos(LeadManagersLongName,"Morgan Stanley")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3+splitmanagername4 if strpos(LeadManagersLongName,"Nomura Securities New York Inc")


replace manager_name_id = splitmanagername1+ splitmanagername2 if strpos(LeadManagersLongName,"Oppenheimer & Co Inc (DO NOT USE after 9/2/2003)" )

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3+splitmanagername4 if strpos(LeadManagersLongName,"Piper Jaffray")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if strpos(LeadManagersLongName,"SG Warburg Securities")

replace manager_name_id = "SGWarburgSZ" if strpos(LeadManagersLongName,"SG Warburg Securities")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if strpos(LeadManagersLongName,"Shearson Lehman")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if strpos(LeadManagersLongName,"Smith Barney")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3+splitmanagername4 if strpos(LeadManagersLongName,"Unterberg Harris")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if strpos(LeadManagersLongName,"Wheat First")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if strpos(LeadManagersLongName,"Faherty")

replace manager_name_id = splitmanagername1+ splitmanagername2+splitmanagername3 if strpos(LeadManagersLongName,"First United")
/******
 NOTE: Oppenheimer & Co Inc (DO NOT USE after 9/2/2003) (?)
*******/


* Prep for merging with CRSP

cap drop issuedate2q
gen issuedate2q = issuedate + 182
format issuedate2q %td

cap drop issuedate2qdow
gen issuedate2qdow = dow(issuedate2q)
rename CRSPPERM permno
save SDC_Akkus_formerge.dta,replace



* Step 1-3. Importing Jay Ritter's Underwriter-reputation measures (underwriter level)

**----(1) Clearning the data by Jay Ritter----**
import excel Underwriter-Rank.xls,clear firstrow
keep UnderwriterName Rank8084 Rank8591 Rank9200 Rank0104 Rank0507 Rank0809 Rank1011 Rank1217 Rank1820

foreach var of varlist Rank*{
	replace `var' = . if `var' == -9
}

forvalue year = 1980/2020{
	cap drop Rank`year'
	gen Rank`year' =.
	replace Rank`year' = Rank8084 if `year'>=1980 & `year'<=1984
	replace Rank`year' = Rank8591 if `year'>=1985 & `year'<=1991
	replace Rank`year' = Rank9200 if `year'>=1992 & `year'<=2000
	replace Rank`year' = Rank0104 if `year'>=2001 & `year'<=2004
	replace Rank`year' = Rank0507 if `year'>=2005 & `year'<=2007
	replace Rank`year' = Rank0809 if `year'>=2008 & `year'<=2009
	replace Rank`year' = Rank1011 if `year'>=2010 & `year'<=2011
	replace Rank`year' = Rank1217 if `year'>=2012 & `year'<=2017
	replace Rank`year' = Rank1820 if `year'>=2018 & `year'<=2020
}

drop Rank8084 Rank8591 Rank9200 Rank0104 Rank0507 Rank0809 Rank1011 Rank1217 Rank1820

cap drop uwid
gen uwid = _n

cap drop splitmanagername*
split UnderwriterName,gen(splitmanagername)

cap drop manager_name_id
gen manager_name_id = splitmanagername1
replace manager_name_id = splitmanagername1+ splitmanagername2

drop if UnderwriterName == ""
drop if UnderwriterName == "-9.000 means no activity"
save CM_wide.dta,replace

use CM_wide.dta,clear

cap drop UW_N
bysort manager_name_id:gen UW_N = _N
cap drop UW_n
bysort manager_name_id:gen UW_n = _n

drop if manager_name_id == "ABNAMRO"
replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"AmeriCorp")
replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"BMO")
replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Bear Stearns International")
drop if UnderwriterName == "Blunt Ellis & Simmons"
replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3+ splitmanagername4 if strpos(UnderwriterName,"Credit Suisse")
drop if UnderwriterName == "Cleary Gull Reiland McDevitt"
drop if UnderwriterName == "Credit Suisse First Boston Int"
drop if UnderwriterName == "Conning & Co" & UW_n == 2
foreach var of varlist Rank1985-Rank1991{
	replace `var' = 7.0009999 if UnderwriterName == "County NatWest Securities Ltd"
}
drop if UnderwriterName == "County NatWest Limited"
replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Credit Agricole")
replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Credit Lyonnais")
drop if UnderwriterName == "Dain Rauscher Wessels"

drop if UnderwriterName == "D. H. Blair Investment Banking"
replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"D. H.")

drop if UnderwriterName == "Daiwa Securities"
drop if UnderwriterName == "Daiwa Securities (New York)"
drop if strpos(UnderwriterName,"Dean Witter")&UnderwriterName != "Dean Witter Reynolds Inc"

foreach var of varlist Rank1985-Rank1991{
	replace `var' = 9.0010004 if UnderwriterName == "Deutsche Bank Securities Corp"
}

drop if strpos(UnderwriterName,"Deutsche")&UnderwriterName != "Deutsche Bank Securities Corp"


foreach var of varlist Rank1980-Rank1984{
	replace `var' = 2.0009999 if UnderwriterName == "Eastern Capital Securities"
}
drop if UnderwriterName == "Eastern Capital"

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Faherty")

drop if strpos(UnderwriterName,"First Union")& UW_n>=2

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"First United")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Foster")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 + splitmanagername4 + splitmanagername5 if strpos(UnderwriterName,"Friedman")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Furman")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3+splitmanagername4 if strpos(UnderwriterName,"Goldman Sachs")
replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3+splitmanagername4 if strpos(UnderwriterName,"Hanifen")

drop if UnderwriterName == "Howe Barnes Investments Inc."

drop if UnderwriterName == "Institutional Equity Holdings"

foreach var of varlist Rank1985-Rank1991{
	replace `var' = 2.0009999 if UnderwriterName == "International Securities"
}

drop if UnderwriterName == "International Securities Group"

drop if UnderwriterName == "Interstate/Johnson Lane Inc" & UW_n == 2

foreach var of varlist Rank1985-Rank1991{
	replace `var' = 7.0009999 if UnderwriterName == "J Henry Schroder & Co Ltd"
}

drop if UnderwriterName == "J Henry Schroder Wagg & Co Ltd"

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"JP Morgan Securities Inc")

foreach var of varlist Rank1980-Rank1984{
	replace `var' = 8.0010004 if UnderwriterName == "Kleinwort Benson Securities"
}

foreach var of varlist Rank1985-Rank1991{
	replace `var' = 6.75 if UnderwriterName == "Kleinwort Benson Securities"
}
drop if UnderwriterName == "Kleinwort Benson Ltd" | UnderwriterName == "Kleinwort Benson North America"

drop if UnderwriterName == "Lazard Freres et Cie"

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3+splitmanagername4 if strpos(UnderwriterName,"Lehman Brothers")

foreach var of varlist Rank1980-Rank1984{
	replace `var' =  2.0009999 if UnderwriterName == "M. H. Meyerson"
}

drop if UnderwriterName == "M. H. Novick"

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3+splitmanagername4 if strpos(UnderwriterName,"Merrill Lynch")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3+splitmanagername4 if strpos(UnderwriterName,"Morgan Stanley")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3+splitmanagername4 if strpos(UnderwriterName,"NM Rothschild")

drop if UnderwriterName == "National Securities (Taiwan)"

drop if UnderwriterName == "Nesbitt Burns Inc" | UnderwriterName == "Nesbitt Burns Securities"

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3+splitmanagername4 if strpos(UnderwriterName,"New York")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3+splitmanagername4 if strpos(UnderwriterName,"Nikko Securities")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3+splitmanagername4 if strpos(UnderwriterName,"Nomura Securities")

drop if UnderwriterName == "Paribas Capital Markets Group"

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3+splitmanagername4 if strpos(UnderwriterName,"Piper Jaffray")

drop if UnderwriterName == "R. D. White & Co."

drop if UnderwriterName == "RBC Dominion Securities Corp"

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Rauscher Pierce")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Robert Fleming")


drop if UnderwriterName == "SBC Warburg Dillon Read Inc"

replace manager_name_id = "SGWarburgSZ" if UnderwriterName == "SG Warburg & Co Inc (SZ)"

drop if UnderwriterName == "SG Warburg & Co. Ltd."

drop if UnderwriterName == "Salomon Smith Barney Interntl"


replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Sanders Morris")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Scotia Capital")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Security Capital")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 + splitmanagername4 if strpos(UnderwriterName,"Simmons &")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Smith Barney")

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Societe Generale")



foreach var of varlist Rank1980-Rank1984{
	replace `var' =  2.0009999 if UnderwriterName == "State Street Capital Markets"
}
drop if UnderwriterName == "State Street Securities"
drop if UnderwriterName == "Stifel Nicolaus Weisel"

drop if UnderwriterName == "Tucker Anthony Cleary Gull"

replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 + splitmanagername4 if strpos(UnderwriterName,"Unterberg Harris")
replace manager_name_id = splitmanagername1+ splitmanagername2+ splitmanagername3 if strpos(UnderwriterName,"Wheat First")

replace manager_name_id = "WRHambrecht" if strpos(UnderwriterName,"W.R. Hambrecht & Company")

drop if UnderwriterName == "Yves Hentic Investment Secs"

cap drop UW_N
bysort manager_name_id:gen UW_N = _N

reshape long Rank, i(uwid) j(issueyear)
cap drop splitmanagername* UW_n UW_N

save CM_long.dta,replace

*----(2) Merging the SDC data with the underwriters' reputation measures----*

use SDC_Akkus_formerge.dta,clear
merge m:1 issueyear manager_name_id using CM_long.dta
drop if _merge == 2

replace manager_name_id = "BA" if strpos(UnderwriterName,"BA Securities")
replace manager_name_id = "Barclays" if strpos(UnderwriterName,"Barclay Investments, Inc.")
replace manager_name_id = "Brean" if strpos(UnderwriterName,"Brean Murray & Co Inc")
replace manager_name_id = "CraigHallum" if strpos(UnderwriterName,"Craig-Hallum, Inc.")
replace manager_name_id = "CreditSuisse" if strpos(UnderwriterName,"Credit Suisse First Boston")
replace manager_name_id = "JPMorgan" if strpos(UnderwriterName,"JP Morgan")
replace manager_name_id = "Merrill" if strpos(UnderwriterName,"Merrill")
replace manager_name_id = "Noble" if strpos(UnderwriterName,"Noble")
replace manager_name_id = "Piper" if strpos(UnderwriterName,"Piper")
replace manager_name_id = "Stephens" if strpos(UnderwriterName,"Stephens Inc")
replace manager_name_id = "SterneAgee" if strpos(UnderwriterName,"SterneAgee")
replace manager_name_id = "Wedbush" if strpos(UnderwriterName,"Wedbush")
replace CUSIP8 = CUSIP8 + "0" if length(CUSIP8)==8

save SDC_Akkus_formerge.dta,replace



* Step 1-4. Importing CPI by BLS

import excel cpi_bls.xlsx,clear cellrange(A12:M140) firstrow


cap drop cpi_year

gen cpi_year = (Jan + Feb + Mar + Apr + May + Jun + Jul + Aug + Sep + Oct + Nov + Dec)/12

gen cpi_2000 = cpi_year if Year == 2000
egen cpi_adj_2000 = max(cpi_2000)
replace cpi_adj_2000 = cpi_year/cpi_adj_2000

keep Year cpi_adj_2000
rename Year cpi_year
keep if cpi_adj_2000 !=.
save cpi_bls.dta,replace


 

* Step 1-5. Importing CRSP data

* (1) Exporting PERMNO list to download CRSP from WRDS
use SDC_Akkus_formerge.dta,clear
sort permno
keep if permno !=.

cap drop permno_n permno_N
bysort permno: gen permno_n = _n
bysort permno: gen permno_N = _N

keep permno
export delimited CRSPPERM_list.txt,novarnames replace

* (2) Download CRSP for the firms with the above PERMNOs

/*
Save the data with CSV extention and name it "Akkus_CRSP.csv"
*/

* (3) Clearning CRSP and merge with the SDC

import delimited Akkus_CRSP.csv,clear

tostring date,replace
gen date_ = date(date,"YMD")
move date_ date
format date_ %td
drop date
rename date_ date

*--Elimitate the duplicated daily data--*
cap drop permno_date_n
bysort permno date: gen permno_date_n = _n
keep if permno_date_n == 1
drop permno_date_n
*---------------------------------------*

xtset permno date
cap drop date_dow
gen date_dow = dow(date)

rename date date4merge

keep permno date4merge shrout prc vwretd
keep if prc!=.&shrout!=.
save Akkus_CRSP4merge.dta,replace

*---First Attempt : Matching on the IPO issuing date---*

use SDC_Akkus_formerge.dta,clear
rename issuedate date4merge
drop if permno == .
cap drop _merge
merge 1:1 permno date4merge using Akkus_CRSP4merge.dta
rename _merge mergeissuedate
drop if mergeissuedate==2
foreach var of varlist prc shrout vwretd{
	rename `var' `var'_1stday
}

*---Second Attempt : Matching on the day after the IPO issuing date---*

rename date4merge issuedate
cap drop issuedatedow issue2day
gen issuedatedow = dow(issuedate)
gen issue2day = issuedate+1 if (issuedatedow >=1&issuedatedow <=4)|issuedatedow == 7
replace issue2day = issuedate+3 if issuedatedow ==5
replace issue2day = issuedate+2 if issuedatedow ==6

rename issue2day date4merge
cap drop _merge
merge 1:1 permno date4merge using Akkus_CRSP4merge.dta
drop if _merge==2
foreach var of varlist prc shrout vwretd{
	cap drop `var'_2ndday
	gen `var'_2ndday = `var'
}
rename _merge merge2day

*---Fetch the price data second quarters after the IPO

rename date4merge issue2day
rename issuedate2q date4merge
cap drop _merge
merge 1:1 permno date4merge using Akkus_CRSP4merge.dta
rename _merge merge2q
drop if merge2q ==2
foreach var of varlist prc shrout vwretd{
	rename `var' `var'_2q
}
rename date4merge issuedate2q
/*
Merging rate, CRSP and SDC
*/
tab mergeissuedate merge2day
tab merge2day merge2q
tab mergeissuedate merge2q

* Keep if CRSP data is available either on the issueday or the next day
drop if mergeissuedate==1&merge2day==1

*---Calculating underpricing and the market values

cap drop underpricing udprc_1stday udprc_2ndday  mktvalue logmktvalue

su prc*

*--- Bid-ask mid prices are reported as negaitve values so reverting
foreach var of varlist prc*{
	replace `var' = abs(`var') if `var' != 0.0
	replace `var' = . if `var' == 0.0
}

su prc*

destring OfferPrice,replace

gen udprc_1stday = ( prc_1stday - OfferPrice ) / OfferPrice
gen udprc_2ndday = ( prc_2ndday - OfferPrice ) / OfferPrice
gen underpricing = udprc_1stday
replace underpricing = udprc_2ndday if udprc_1stday==.

su underpricing

*--- Fetching CPI index to adjust the market value in the second quarter

cap drop cpi_year
gen cpi_year = year(issuedate2q)
cap drop _merge
merge m:1 cpi_year using cpi_bls.dta
keep if _merge == 3
drop _merge
*--- Make the market value CPI-adjusted

cap drop  mktvalue logmktvalue
gen mktvalue = prc_2q * shrout_2q / cpi_adj_2000
*--- Note: the market value is in thousands
replace mktvalue = mktvalue/1000
label variable mktvalue "Market value (in thousands)"
gen logmktvalue = log(mktvalue)
su mktvalue logmktvalue

save Akkus_SDC_CRSP_matched.dta,replace

* use Akkus_SDC_CRSP_matched.dta,clear

* (4) Calculate the Hoberg's (2007) measure of underwriter average underpricing
cap drop issuemonth
gen issuemonth = month(issuedate)

cap drop undprc_yearavg undprc_uwyearavg und_prc_dif
bysort issueyear issuemonth: egen undprc_monthavg = mean(underpricing)
bysort issueyear manager_name_id: egen undprc_uwyearavg = mean(underpricing)

cap drop undprc_dif
gen undprc_dif = underpricing - undprc_monthavg
su undprc_dif

cap drop IPO_count_by_uw
cap drop uw_id
encode manager_name_id,gen(uw_id)
sort manager_name_id issuedate
cap drop uw_year_n uw_year_N
bysort manager_name_id issueyear: gen uw_year_n =_n
by manager_name_id issueyear: gen uw_year_N =_N


*-- Calculate rolling average within the year

sort uw_id issuedate
cap drop uw_year_id
egen uw_year_id = group(uw_id issueyear) 
*------ Rolling count within the year
cap drop withinyear_uw_n
bysort uw_year_id: gen withinyear_uw_n =_n
xtset uw_year_id withinyear_uw_n
cap drop undprc_within_total
*------ Rolling sum wihtin the year
tsegen undprc_within_total = rowtotal(L(1/100).undprc_dif)

save temp.dta,replace
* use temp.dta,clear

*-- Calculate rolling average over the last five years (excluding that year)

cap drop undprc_dif_yearsum
cap drop  uw_year_N
bysort uw_id issueyear : egen undprc_dif_yearsum = sum(undprc_dif)
bysort uw_id issueyear : gen uw_year_N = _N
keep if uw_year_n == 1
keep issueyear manager_name_id undprc_dif_yearsum uw_id uw_year_N

xtset uw_id issueyear
cap drop undprc_fiveyear_total rollingcount_fiveyear_total
tsegen undprc_fiveyear_total = rowtotal(L(1/4).undprc_dif_yearsum)
tsegen rollingcount_fiveyear_total = rowtotal(L(1/4).uw_year_N)
save undprc_year_panel.dta,replace
use temp.dta,clear

merge m:1 issueyear manager_name_id using undprc_year_panel.dta
drop _merge


cap drop hoberg_undprc
gen hoberg_undprc = (undprc_within_total+undprc_fiveyear_total)/(withinyear_uw_n-1+rollingcount_fiveyear_total)
replace hoberg_undprc =. if withinyear_uw_n == 1& rollingcount_fiveyear_total ==0

su hoberg_undprc if issueyear>=1985&issueyear<=2010

save temp.dta,replace
* Step 1-6. Importing Compustat

*---- Importing Compustat via WRDS ---*

* The linking table of CRSP and COMPUSTAT from WRDS

* New attempt: use the CRSP/COMPUSTAT table
* Use CSRPPERM_list.txt and download the table from WRDS

import delimited CRSP_COMPUSTAT_table.csv,clear
keep if gvkey!=.
rename lpermno permno
keep permno gvkey

cap drop permno_gvkey_n
bysort permno gvkey:gen permno_gvkey_n=_n
keep if permno_gvkey_n==1

cap drop permno_N
bysort permno:gen permno_N=_N

cap drop gvkey_N
bysort gvkey:gen gvkey_N= _N
* drop for now
drop if gvkey_N>=2

save Akkus_permno_gvkey.dta,replace
keep gvkey
export delimited Akkus_gvkey_list.txt,novarnames replace


* Download COMPUSTAT from WRDS
import delimited Akkus_COMPSTAT19802017_gvkey.csv,clear
rename fyear issueyear
rename tic Ticker
rename at totalasset

merge m:1 gvkey using Akkus_permno_gvkey.dta
keep if _merge == 3
cap drop _merge

save Akkus_COMPSTAT19802017_gvkey.dta,replace


*---- Merging with SDC/CRSP data ---*

use temp.dta,clear
cap drop _merge
merge 1:m permno issueyear using Akkus_COMPSTAT19802017_gvkey.dta
keep if _merge == 3

cap drop logasset
gen logasset = log(totalasset)
su logasset if issueyear>=1985&issueyear<=2010

save Akkus_SDC_CRSP_COMPUSTAT_CM_matched.dta,replace


* Step 1-7. Importing Thompson F13 Data (underwriter level)

keep Ticker issuedate
keep if Ticker!=""
cap drop Ticker_n
bysort Ticker: gen Ticker_n=_n
keep if Ticker_n == 1
drop Ticker_n
save Akkus_SDC_Thompson_Ticker_list.dta,replace

*--- Importing Thomson_f13 from WRDS ---*

use Thomson_f13.dta,clear

keep if ticker!=""
rename ticker Ticker
merge m:1 Ticker using Akkus_SDC_Thompson_Ticker_list.dta
sort Ticker mgrno fdate

cap drop issueyear issuemonth issueday
gen issueyear = year(issuedate)
gen issuemonth = month(issuedate)
gen issueday = day(issuedate)

cap drop issuequarter
gen issuequarter = 1 if month(issuedate)<=3
replace issuequarter = 2 if month(issuedate)>=4&month(issuedate)<=6
replace issuequarter = 3 if month(issuedate)>=7&month(issuedate)<=9
replace issuequarter = 4 if month(issuedate)>=10&month(issuedate)<=12


cap drop first_quarter
gen first_quarter = .
replace first_quarter = (year(issueyear)==year(fdate)&month(fdate)>=1&month(fdate)<=3) if issuequarter == 1 
replace first_quarter = (year(issueyear)==year(fdate)&month(fdate)>=4&month(fdate)<=6) if issuequarter == 2 
replace first_quarter = (year(issueyear)==year(fdate)&month(fdate)>=7&month(fdate)<=9) if issuequarter == 3 
replace first_quarter = (year(issueyear)==year(fdate)&month(fdate)>=10&month(fdate)<=12) if issuequarter == 4 

cap drop comb_fund_stock
egen comb_fund_stock = group(mgrno Ticker)

keep if shares!=.
cap drop comb_fund_stock_fdate_n
bysort comb_fund_stock fdate:gen comb_fund_stock_fdate_n = _n
keep if comb_fund_stock_fdate_n==1



cap drop informed_time
gen informed_time = (issuequarter==1&year(fdate)==year(issuedate))
replace informed_time = (issuequarter==2&((year(fdate)==year(issuedate)&month(fdate)>=4&month(fdate)<=12)|(year(fdate)+1==year(issuedate)&month(fdate)>=1&month(fdate)<=3))) if informed_time==0
replace informed_time = (issuequarter==3&((year(fdate)==year(issuedate)&month(fdate)>=7&month(fdate)<=12)|(year(fdate)+1==year(issuedate)&month(fdate)>=1&month(fdate)<=6))) if informed_time==0
replace informed_time = (issuequarter==4&((year(fdate)==year(issuedate)&month(fdate)>=10&month(fdate)<=12)|(year(fdate)+1==year(issuedate)&month(fdate)>=1&month(fdate)<=9))) if informed_time==0


cap drop quarter
egen quarter = group(fdate)
xtset comb_fund_stock quarter
cap drop change_rate
gen change_rate = (shares-l.shares)/l.shares
cap drop informed
gen informed = (change_rate>=0.5)
count if informed==1
keep if informed_time == 1
cap drop informed_fund fund_N fund_time_n
bysort Ticker mgrno: egen informed_fund = max(informed)
sort Ticker mgrno fdate
cap drop fund_stock_time
by Ticker mgrno:gen fund_stock_time = _n
keep if fund_stock_time == 1
cap drop fund_N_by_stock fund_n_by_stock 
bysort Ticker:gen fund_N_by_stock =_N
bysort Ticker:gen fund_n_by_stock =_n

cap drop informed_fraction
gen informed_fraction = informed_fund/fund_N_by_stock
keep if fund_n_by_stock == 1

su informed_fraction

keep Ticker stkname informed_fraction
save Thompson_f13_informed_19802017.dta,replace

*-- Calculating the rolling averages --*

use Akkus_SDC_CRSP_COMPUSTAT_CM_matched.dta,clear

cap drop _merge
merge m:1 Ticker using Thompson_f13_informed_19802017
drop _merge
cap drop informed_fraction_uw_year
bysort  issueyear uw_id:egen informed_fraction_uw_year = mean(informed_fraction)

* save temp.dta,replace
* use temp.dta,clear
cap drop uw_id_year_n
bysort uw_id issueyear: gen uw_id_year_n = _n 
keep if uw_id_year_n == 1
keep issueyear uw_id informed_fraction_uw_year
keep if uw_id !=.
xtset uw_id issueyear
cap drop informed_rolling_avg
tsegen informed_rolling_avg = rowtotal(L(1/4).informed_fraction_uw_year)
keep issueyear uw_id informed_rolling_avg
save Thomspon_f13_informed_UW_rollingavg.dta,replace

*-- Merging with SDC/CRSP/COMPUSTAT data --*

use Akkus_SDC_CRSP_COMPUSTAT_CM_matched.dta,clear
cap drop _merge
merge m:1 uw_id issueyear using Thomspon_f13_informed_UW_rollingavg.dta
drop _merge
save Akkus_SDC_CRSP_CM_Thompson_matched.dta,replace



* (Step 1-8. Importing IBES, year-underwriter level) 
/*
This step is not necessary for the Akkus paper
*/


*-- Linking the underwriters' names and ESTIMIDs

use Akkus_SDC_CRSP_CM_Thompson_matched.dta,replace

cap drop Manager_N Manager_N_after1993 Manager_n Manager_n_after1993
bysort LeadManagersLongName: gen Manager_N =_N
bysort LeadManagersLongName: gen Manager_N_after1993 =_N if issueyear>=1993

bysort LeadManagersLongName: gen Manager_n =_n
bysort LeadManagersLongName: gen Manager_n_after1993 =_n if issueyear>=1993

cap drop start_year end_year
bysort LeadManagersLongName: egen start_year = min(issueyear)
bysort LeadManagersLongName: egen end_year = max(issueyear)


save temp.dta,replace

keep if Manager_n == 1
keep LeadManagersLongName Manager_N start_year end_year
sort Manager_N
export delimited SDC_IPO_ranking_19802017.csv,replace

use temp.dta,clear
keep if Manager_n_after1993 == 1
keep LeadManagersLongName Manager_N_after1993 start_year end_year
sort Manager_N_after1993
export delimited SDC_IPO_ranking_19932017.csv,replace
save SDC_IPO_ranking_19932017.dta,replace


* using the handmatching table
import delimited BrokerNames_SDC_JR_after1993_handmatched.csv,clear
rename leadmanagerslongname LeadManagersLongName
cap drop ESTIMID*
split estimid,gen(ESTIMID) parse("/")
save SDC_Leadname_ESTIMID.dta,replace

use SDC_IPO_ranking_19932017.dta,clear
merge 1:1 LeadManagersLongName using SDC_Leadname_ESTIMID.dta

drop _merge

keep LeadManagersLongName ESTIMID*
save SDC_ESTIMID_linkingtable.dta,replace


use Akkus_SDC_CRSP_CM_matched.dta,clear
sort LeadManagersLongName
cap drop _merge
drop if LeadManagersLongName == "Not Applicable"
merge m:1 LeadManagersLongName using SDC_ESTIMID_linkingtable.dta

drop _merge

cap drop start_year end_year
bysort LeadManagersLongName: egen start_year = min(issueyear)
bysort LeadManagersLongName: egen end_year = max(issueyear)

replace ESTIMID1 = "RYANBECK" if LeadManagersLongName == "Ryan Beck & Co"
replace ESTIMID1 = "AEGISCAP" if LeadManagersLongName == "Aegis Capital Corp."
replace ESTIMID1 = "MDB" if LeadManagersLongName == "MDB Capital Corp"

cap drop ESTIMID_recovered
gen ESTIMID_recovered = (ESTIMID1 !="")
su ESTIMID_recovered if issueyear>=1993


cap drop Manager_N Manager_N_after1993 Manager_n Manager_n_after1993
bysort LeadManagersLongName: gen Manager_N =_N

bysort LeadManagersLongName: gen Manager_n =_n


save Akkus_SDC_UW_ESTIMD_full.dta,replace

keep if issueyear>=1993

cap drop Manager_N_after1993 Manager_n_after1993
bysort LeadManagersLongName: gen Manager_N_after1993 =_N
bysort LeadManagersLongName: gen Manager_n_after1993 =_n

cap drop ESTIMID
gen ESTIMID = ESTIMID1 if ESTIMID2 == ""
replace ESTIMID = "HAMPSEC" if ESTIMID1 == "HAMPSEC"
replace ESTIMID = "LADENBRG" if ESTIMID1 == "LADENBRG" & issueyear<=2005
replace ESTIMID = "LADENBUR" if ESTIMID1 == "LADENBRG" & issueyear>=2006
replace ESTIMID = "OPPEN" if LeadManagersLongName == "Oppenheimer & Co Inc"

keep if IPOName !=""
save Akkus_SDC_UW_ESTIMD_19932017.dta,replace




*-- Importing forecast estimates from IBES --*

/*
Need to recover ESTIMID in the 
Using the Kelvin Law's linking table
*/


use "21-11-10 estimator estimid usfirm linking table by Kelvin Law.dta",clear
keep if usfirm == 1

cap drop temp_count
bysort estimator:gen temp_count = _N
drop if temp_count >=2
* Drop them for now
drop temp_count

save KelvinLaw_ESTIMID_estimator_linkingtable.dta,replace

import delimited IBES_dh_quarter.csv,clear

cap drop ANNDATS ann_year
gen ANNDATS = daily(string(anndats, "%8.0f"), "YMD") 
format anndats %8.0f 
format ANNDATS %td
gen ann_year = year(ANNDATS)

keep if value !=. & actual != .

cap drop raw_error error_sqrt error_abs optim
gen raw_error = value - actual
gen error_sqrt = sqrt(raw_error^2)/abs(actual)
gen error_abs = abs(raw_error/actual)
gen optim = (raw_error>0)

merge m:1 estimator using KelvinLaw_ESTIMID_estimator_linkingtable.dta
keep if _merge == 3 
drop _merge

rename estimid ESTIMID


foreach var of varlist raw_error error_sqrt error_abs optim{
cap drop yearavg_`var'
bysort ESTIMID ann_year: egen 	IBES_avg_`var' = mean(`var')
}

cap drop year_forecast_amount
bysort ESTIMID ann_year: gen IBES_forecast_amount = _N

cap drop ESTIMID_year_n
bysort ESTIMID ann_year: gen ESTIMID_year_n = _n
keep if ESTIMID_year_n == 1

keep IBES* ESTIMID ann_year
reshape wide IBES*,i(ESTIMID) j(ann_year)

save IBES_dh_quarter_wide_ESTIMID_matched.dta,replace


use Akkus_SDC_UW_ESTIMD_19932017.dta,clear
cap drop _merge
merge m:1 ESTIMID using IBES_dh_quarter_wide_ESTIMID_matched.dta

keep if _merge == 3
cap drop _merge
foreach var in raw_error error_sqrt error_abs optim{
	cap drop issueyear`var' lastyear`var' twoyearbefore`var' threeyearbefore`var' lastthreeyears`var'
	gen issueyear`var'=.
	gen lastyear`var' = .
	gen twoyearbefore`var' =.
	gen threeyearbefore`var' =.
	forvalues yr = 1993/2017{
	replace	issueyear`var'=IBES_avg_`var'`yr' if issueyear == `yr'
	local lastyear = `yr' - 1
	replace	lastyear`var'=IBES_avg_`var'`lastyear' if issueyear == `yr'
	local twoyearback = `yr'-2
	replace	twoyearbefore`var'=IBES_avg_`var'`twoyearback' if issueyear == `yr'
	local threeyearback = `yr'-3
	replace	threeyearbefore`var'=IBES_avg_`var'`threeyearback' if issueyear == `yr'	
	}
	gen lastthreeyears`var'= (lastyear`var'+twoyearbefore`var'+threeyearbefore`var')/3
}

	cap drop issueyearforecast_amount lastyearforecast_amount twoyearbeforeforecast_amount threeyearbeforeforecast_amount lastthreeyearsforecast_amount
	gen issueyearforecast_amount=.
	gen lastyearforecast_amount = .
	gen twoyearbeforeforecast_amount =.
	gen threeyearbeforeforecast_amount =.
	forvalues yr = 1993/2017{
	replace	issueyearforecast_amount=IBES_forecast_amount`yr' if issueyear == `yr'
	local lastyear = `yr' - 1
	replace	lastyearforecast_amount=IBES_forecast_amount`lastyear' if issueyear == `yr'
	local twoyearback = `yr'-2
	replace	twoyearbeforeforecast_amount=IBES_forecast_amount`twoyearback' if issueyear == `yr'
	local threeyearback = `yr'-3
	replace	threeyearbeforeforecast_amount=IBES_forecast_amount`threeyearback' if issueyear == `yr'
	}
	gen lastthreeyearsforecast_amount= (lastyearforecast_amount+twoyearbeforeforecast_amount+threeyearbeforeforecast_amount)/3

cap drop ESTIMID_year_N ESTIMID_year_n
bysort ESTIMID issueyear: gen ESTIMID_year_N = _N if ESTIMID !=""
bysort ESTIMID issueyear: gen ESTIMID_year_n = _n if ESTIMID !=""


label variable issueyearraw_error "Raw error in the issue year"
label variable lastyearraw_error "Raw error in the last year"
label variable twoyearbeforeraw_error "Raw error two year back"
label variable  threeyearbeforeraw_error "Raw error three year back"
label variable  lastthreeyearsraw_error "Raw error in the last three years"
label variable  issueyearerror_sqrt "RSME in the issue year"
label variable  lastyearerror_sqrt "RSME in the last year"
label variable  twoyearbeforeerror_sqrt "RSME in two year back"
label variable  threeyearbeforeerror_sqrt "RSME in three year back"
label variable  lastthreeyearserror_sqrt "RSME in the last three years"
label variable  issueyearerror_abs "Absolute errors in the issue year"
label variable  lastyearerror_abs "Absolute errors in the last year"
label variable  twoyearbeforeerror_abs "Absolute errors in two year back"
label variable  threeyearbeforeerror_abs "Absolute errors in three year back"
label variable  lastthreeyearserror_abs "Absolute errors in the last three years"
label variable  issueyearoptim "Optimistic forecast rate in the issue year"
label variable  lastyearoptim "Optimistic forecast rate in the last year"
label variable  twoyearbeforeoptim "Optimistic forecast rate in two year back"
label variable  threeyearbeforeoptim "Optimistic forecast rate in three year back"
label variable  lastthreeyearsoptim "Optimistic forecast rate in the last three years"
label variable  issueyearforecast_amount "Number of forecasts in the issue year"
label variable  lastyearforecast_amount "Number of forecasts in the last year"
label variable  twoyearbeforeforecast_amount "Number of forecasts in two year back"
label variable  threeyearbeforeforecast_amount "Number of forecasts in three year back"
label variable  lastthreeyearsforecast_amount "Number of forecasts in the last three years"
label variable ESTIMID_year_N "Number of IPOs underwriting in the year"
save SDC_IBES_forecasts_matched.dta,replace

keep if ESTIMID_year_n == 1

keep ESTIMID issueyear issueyear* lastyear* twoyearbefore* threeyearbefore* lastthreeyears* *forecast_amount ESTIMID_year_N

save SDC_IBES_forecasts_matched_yearpanel.dta,replace


*--- Importing recommendation files from IBES --*


use IBES_rec_det.dta,clear

cap drop issueyear
gen issueyear = year(ANNDATS)

keep if USFIRM == 1
keep if ESTIMID != ""
keep if TICKER !=""
keep if issueyear>=1993&issueyear<=2017
cap drop concensus ESTIMID_TICKER_year_N aggress_rec strong_buy ESTIMID_TICKER_year_N ESTIMID_rec_N ESTIMID_covering_firm_N
destring IRECCD,replace
bysort issueyear TICKER:egen concensus = median(IRECCD)
gen aggress_rec = (IRECCD <concensus) if IRECCD !=.
gen strong_buy =(IRECCD==1)
bysort ESTIMID TICKER issueyear: gen ESTIMID_TICKER_year_N = _N
bysort ESTIMID issueyear: gen ESTIMID_rec_N = _N
cap drop test_group
sort ESTIMID issueyear TICKER
egen test_group = group(ESTIMID issueyear TICKER)
cap drop min_group max_group ESTIMID_rec_covering_firm_N
bysort ESTIMID issueyear:egen min_group = min(test_group) 
bysort ESTIMID issueyear:egen max_group = max(test_group) 
gen ESTIMID_rec_covering_firm_N = max_group-min_group+1
* Aggregate to year-ESTIMID level
cap drop aggress_rec_rate strong_buy_rate
bysort ESTIMID issueyear: egen aggress_rec_rate = mean(aggress_rec)
bysort ESTIMID issueyear: egen strong_buy_rate = mean(strong_buy)

cap drop ESTIMID_issueyear_n
bysort ESTIMID issueyear: gen ESTIMID_issueyear_n = _n
keep if ESTIMID_issueyear_n == 1
* Merging the last year's data
rename issueyear ann_year
cap drop issueyear
gen issueyear = ann_year + 1
keep ESTIMID issueyear ESTIMID_rec_covering_firm_N aggress_rec_rate strong_buy_rate
su ESTIMID_rec_covering_firm_N aggress_rec_rate strong_buy_rate
save SDC_IBES_rec_matched_yearpanel.dta,replace

*--- Merging the IBES with SDC/CRSP/COMPUSTAT/Thompson


use Akkus_SDC_CRSP_CM_Thompson_matched.dta,clear
cap drop _merge
cap drop temp_count
bysort IPOName issuedate:gen temp_count = _n
keep if temp_count==1
drop temp_count
cap drop _merge
replace IPOName = upper(IPOName)
merge 1:1 IPOName issuedate using Akkus_SDC_UW_ESTIMD_19932017.dta
rename _merge mergeESTIMID
merge m:1 issueyear ESTIMID using SDC_IBES_rec_matched_yearpanel.dta
replace ESTIMID_rec_covering_firm_N = 0 if ESTIMID!=""&ESTIMID_rec_covering_firm_N==.
drop if _merge == 2
drop _merge

merge m:1 issueyear ESTIMID using SDC_IBES_forecasts_matched_yearpanel.dta
drop if _merge == 2
drop _merge

save SDC_IBES_merged_master_19932017.dta,replace


*--- Market attributes --- *

use CRSP_mktret.dta,clear
cap drop time
gen time = _n
tsset time
foreach var of varlist vwretd vwretx ewretd ewretx sprtrn{
	cap drop `var'_15daymean
	cap drop `var'_15daysd
	tsegen `var'_15daymean = rowmean(L(1/15).`var')
	tsegen `var'_15daysd = rowsd(L(1/15).`var')
}
rename DATE issuedate
keep issuedate *_15daymean *_15daysd

save CRSP_15day.dta,replace
use CRSP_15day.dta,replace
use SDC_IBES_merged_master_19932017.dta,replace

cap number_ipos_month averageup_month

bysort issueyear issuemonth: gen number_ipos_month = _N
bysort issueyear issuemonth: egen averageup_month = mean(underpricing)

keep if number_ipos_month !=. & averageup_month !=.

cap drop month_count
sort issueyear issuemonth
egen month_count = group(issueyear issuemonth)

keep issuedate issueyear issuemonth month_count number_ipos_month averageup_month

cap drop withinmonth_n
bysort issueyear issuemonth:gen withinmonth_n = _n 
keep if withinmonth_n == 1
drop withinmonth_n
tsset month_count
cap drop averageup_lastmonth number_ipos_lastmonth
gen averageup_lastmonth = l.averageup_month
gen number_ipos_lastmonth = l.number_ipos_month

save IPO_market_attributes.dta,replace

use SDC_IBES_merged_master_19932017.dta,replace
cap drop _merge
merge m:1 issuedate using CRSP_15day.dta
keep if _merge ==3
drop _merge
merge m:1 issueyear issuemonth using IPO_market_attributes.dta

cap drop fama_french_industry
gen fama_french_industry =.
replace fama_french_industry =	1	if MainSICCode >=	100	&MainSICCode <=	199
replace fama_french_industry =	1	if MainSICCode >=	200	&MainSICCode <=	299
replace fama_french_industry =	1	if MainSICCode >=	700	&MainSICCode <=	799
replace fama_french_industry =	1	if MainSICCode >=	910	&MainSICCode <=	919
replace fama_french_industry =	1	if MainSICCode >=	2048	&MainSICCode <=	2048
replace fama_french_industry =	2	if MainSICCode >=	2000	&MainSICCode <=	2009
replace fama_french_industry =	2	if MainSICCode >=	2010	&MainSICCode <=	2019
replace fama_french_industry =	2	if MainSICCode >=	2020	&MainSICCode <=	2029
replace fama_french_industry =	2	if MainSICCode >=	2030	&MainSICCode <=	2039
replace fama_french_industry =	2	if MainSICCode >=	2040	&MainSICCode <=	2046
replace fama_french_industry =	2	if MainSICCode >=	2050	&MainSICCode <=	2059
replace fama_french_industry =	2	if MainSICCode >=	2060	&MainSICCode <=	2063
replace fama_french_industry =	2	if MainSICCode >=	2070	&MainSICCode <=	2079
replace fama_french_industry =	2	if MainSICCode >=	2090	&MainSICCode <=	2092
replace fama_french_industry =	2	if MainSICCode >=	2095	&MainSICCode <=	2095
replace fama_french_industry =	2	if MainSICCode >=	2098	&MainSICCode <=	2099
replace fama_french_industry =	3	if MainSICCode >=	2064	&MainSICCode <=	2068
replace fama_french_industry =	3	if MainSICCode >=	2086	&MainSICCode <=	2086
replace fama_french_industry =	3	if MainSICCode >=	2087	&MainSICCode <=	2087
replace fama_french_industry =	3	if MainSICCode >=	2096	&MainSICCode <=	2096
replace fama_french_industry =	3	if MainSICCode >=	2097	&MainSICCode <=	2097
replace fama_french_industry =	4	if MainSICCode >=	2080	&MainSICCode <=	2080
replace fama_french_industry =	4	if MainSICCode >=	2082	&MainSICCode <=	2082
replace fama_french_industry =	4	if MainSICCode >=	2083	&MainSICCode <=	2083
replace fama_french_industry =	4	if MainSICCode >=	2084	&MainSICCode <=	2084
replace fama_french_industry =	4	if MainSICCode >=	2085	&MainSICCode <=	2085
replace fama_french_industry =	5	if MainSICCode >=	2100	&MainSICCode <=	2199
replace fama_french_industry =	6	if MainSICCode >=	920	&MainSICCode <=	999
replace fama_french_industry =	6	if MainSICCode >=	3650	&MainSICCode <=	3651
replace fama_french_industry =	6	if MainSICCode >=	3652	&MainSICCode <=	3652
replace fama_french_industry =	6	if MainSICCode >=	3732	&MainSICCode <=	3732
replace fama_french_industry =	6	if MainSICCode >=	3930	&MainSICCode <=	3931
replace fama_french_industry =	6	if MainSICCode >=	3940	&MainSICCode <=	3949
replace fama_french_industry =	7	if MainSICCode >=	7800	&MainSICCode <=	7829
replace fama_french_industry =	7	if MainSICCode >=	7830	&MainSICCode <=	7833
replace fama_french_industry =	7	if MainSICCode >=	7840	&MainSICCode <=	7841
replace fama_french_industry =	7	if MainSICCode >=	7900	&MainSICCode <=	7900
replace fama_french_industry =	7	if MainSICCode >=	7910	&MainSICCode <=	7911
replace fama_french_industry =	7	if MainSICCode >=	7920	&MainSICCode <=	7929
replace fama_french_industry =	7	if MainSICCode >=	7930	&MainSICCode <=	7933
replace fama_french_industry =	7	if MainSICCode >=	7940	&MainSICCode <=	7949
replace fama_french_industry =	7	if MainSICCode >=	7980	&MainSICCode <=	7980
replace fama_french_industry =	7	if MainSICCode >=	7990	&MainSICCode <=	7999
replace fama_french_industry =	8	if MainSICCode >=	2700	&MainSICCode <=	2709
replace fama_french_industry =	8	if MainSICCode >=	2710	&MainSICCode <=	2719
replace fama_french_industry =	8	if MainSICCode >=	2720	&MainSICCode <=	2729
replace fama_french_industry =	8	if MainSICCode >=	2730	&MainSICCode <=	2739
replace fama_french_industry =	8	if MainSICCode >=	2740	&MainSICCode <=	2749
replace fama_french_industry =	8	if MainSICCode >=	2770	&MainSICCode <=	2771
replace fama_french_industry =	8	if MainSICCode >=	2780	&MainSICCode <=	2789
replace fama_french_industry =	8	if MainSICCode >=	2790	&MainSICCode <=	2799
replace fama_french_industry =	9	if MainSICCode >=	2047	&MainSICCode <=	2047
replace fama_french_industry =	9	if MainSICCode >=	2391	&MainSICCode <=	2392
replace fama_french_industry =	9	if MainSICCode >=	2510	&MainSICCode <=	2519
replace fama_french_industry =	9	if MainSICCode >=	2590	&MainSICCode <=	2599
replace fama_french_industry =	9	if MainSICCode >=	2840	&MainSICCode <=	2843
replace fama_french_industry =	9	if MainSICCode >=	2844	&MainSICCode <=	2844
replace fama_french_industry =	9	if MainSICCode >=	3160	&MainSICCode <=	3161
replace fama_french_industry =	9	if MainSICCode >=	3170	&MainSICCode <=	3171
replace fama_french_industry =	9	if MainSICCode >=	3172	&MainSICCode <=	3172
replace fama_french_industry =	9	if MainSICCode >=	3190	&MainSICCode <=	3199
replace fama_french_industry =	9	if MainSICCode >=	3229	&MainSICCode <=	3229
replace fama_french_industry =	9	if MainSICCode >=	3260	&MainSICCode <=	3260
replace fama_french_industry =	9	if MainSICCode >=	3262	&MainSICCode <=	3263
replace fama_french_industry =	9	if MainSICCode >=	3269	&MainSICCode <=	3269
replace fama_french_industry =	9	if MainSICCode >=	3230	&MainSICCode <=	3231
replace fama_french_industry =	9	if MainSICCode >=	3630	&MainSICCode <=	3639
replace fama_french_industry =	9	if MainSICCode >=	3750	&MainSICCode <=	3751
replace fama_french_industry =	9	if MainSICCode >=	3800	&MainSICCode <=	3800
replace fama_french_industry =	9	if MainSICCode >=	3860	&MainSICCode <=	3861
replace fama_french_industry =	9	if MainSICCode >=	3870	&MainSICCode <=	3873
replace fama_french_industry =	9	if MainSICCode >=	3910	&MainSICCode <=	3911
replace fama_french_industry =	9	if MainSICCode >=	3914	&MainSICCode <=	3914
replace fama_french_industry =	9	if MainSICCode >=	3915	&MainSICCode <=	3915
replace fama_french_industry =	9	if MainSICCode >=	3960	&MainSICCode <=	3962
replace fama_french_industry =	9	if MainSICCode >=	3991	&MainSICCode <=	3991
replace fama_french_industry =	9	if MainSICCode >=	3995	&MainSICCode <=	3995
replace fama_french_industry =	10	if MainSICCode >=	2300	&MainSICCode <=	2390
replace fama_french_industry =	10	if MainSICCode >=	3020	&MainSICCode <=	3021
replace fama_french_industry =	10	if MainSICCode >=	3100	&MainSICCode <=	3111
replace fama_french_industry =	10	if MainSICCode >=	3130	&MainSICCode <=	3131
replace fama_french_industry =	10	if MainSICCode >=	3140	&MainSICCode <=	3149
replace fama_french_industry =	10	if MainSICCode >=	3150	&MainSICCode <=	3151
replace fama_french_industry =	10	if MainSICCode >=	3963	&MainSICCode <=	3965
replace fama_french_industry =	11	if MainSICCode >=	8000	&MainSICCode <=	8099
replace fama_french_industry =	12	if MainSICCode >=	3693	&MainSICCode <=	3693
replace fama_french_industry =	12	if MainSICCode >=	3840	&MainSICCode <=	3849
replace fama_french_industry =	12	if MainSICCode >=	3850	&MainSICCode <=	3851
replace fama_french_industry =	13	if MainSICCode >=	2830	&MainSICCode <=	2830
replace fama_french_industry =	13	if MainSICCode >=	2831	&MainSICCode <=	2831
replace fama_french_industry =	13	if MainSICCode >=	2833	&MainSICCode <=	2833
replace fama_french_industry =	13	if MainSICCode >=	2834	&MainSICCode <=	2834
replace fama_french_industry =	13	if MainSICCode >=	2835	&MainSICCode <=	2835
replace fama_french_industry =	13	if MainSICCode >=	2836	&MainSICCode <=	2836
replace fama_french_industry =	14	if MainSICCode >=	2800	&MainSICCode <=	2809
replace fama_french_industry =	14	if MainSICCode >=	2810	&MainSICCode <=	2819
replace fama_french_industry =	14	if MainSICCode >=	2820	&MainSICCode <=	2829
replace fama_french_industry =	14	if MainSICCode >=	2850	&MainSICCode <=	2859
replace fama_french_industry =	14	if MainSICCode >=	2860	&MainSICCode <=	2869
replace fama_french_industry =	14	if MainSICCode >=	2870	&MainSICCode <=	2879
replace fama_french_industry =	14	if MainSICCode >=	2890	&MainSICCode <=	2899
replace fama_french_industry =	15	if MainSICCode >=	3031	&MainSICCode <=	3031
replace fama_french_industry =	15	if MainSICCode >=	3041	&MainSICCode <=	3041
replace fama_french_industry =	15	if MainSICCode >=	3050	&MainSICCode <=	3053
replace fama_french_industry =	15	if MainSICCode >=	3060	&MainSICCode <=	3069
replace fama_french_industry =	15	if MainSICCode >=	3070	&MainSICCode <=	3079
replace fama_french_industry =	15	if MainSICCode >=	3080	&MainSICCode <=	3089
replace fama_french_industry =	15	if MainSICCode >=	3090	&MainSICCode <=	3099
replace fama_french_industry =	16	if MainSICCode >=	2200	&MainSICCode <=	2269
replace fama_french_industry =	16	if MainSICCode >=	2270	&MainSICCode <=	2279
replace fama_french_industry =	16	if MainSICCode >=	2280	&MainSICCode <=	2284
replace fama_french_industry =	16	if MainSICCode >=	2290	&MainSICCode <=	2295
replace fama_french_industry =	16	if MainSICCode >=	2297	&MainSICCode <=	2297
replace fama_french_industry =	16	if MainSICCode >=	2298	&MainSICCode <=	2298
replace fama_french_industry =	16	if MainSICCode >=	2299	&MainSICCode <=	2299
replace fama_french_industry =	16	if MainSICCode >=	2393	&MainSICCode <=	2395
replace fama_french_industry =	16	if MainSICCode >=	2397	&MainSICCode <=	2399
replace fama_french_industry =	17	if MainSICCode >=	800	&MainSICCode <=	899
replace fama_french_industry =	17	if MainSICCode >=	2400	&MainSICCode <=	2439
replace fama_french_industry =	17	if MainSICCode >=	2450	&MainSICCode <=	2459
replace fama_french_industry =	17	if MainSICCode >=	2490	&MainSICCode <=	2499
replace fama_french_industry =	17	if MainSICCode >=	2660	&MainSICCode <=	2661
replace fama_french_industry =	17	if MainSICCode >=	2950	&MainSICCode <=	2952
replace fama_french_industry =	17	if MainSICCode >=	3200	&MainSICCode <=	3200
replace fama_french_industry =	17	if MainSICCode >=	3210	&MainSICCode <=	3211
replace fama_french_industry =	17	if MainSICCode >=	3240	&MainSICCode <=	3241
replace fama_french_industry =	17	if MainSICCode >=	3250	&MainSICCode <=	3259
replace fama_french_industry =	17	if MainSICCode >=	3261	&MainSICCode <=	3261
replace fama_french_industry =	17	if MainSICCode >=	3264	&MainSICCode <=	3264
replace fama_french_industry =	17	if MainSICCode >=	3270	&MainSICCode <=	3275
replace fama_french_industry =	17	if MainSICCode >=	3280	&MainSICCode <=	3281
replace fama_french_industry =	17	if MainSICCode >=	3290	&MainSICCode <=	3293
replace fama_french_industry =	17	if MainSICCode >=	3295	&MainSICCode <=	3299
replace fama_french_industry =	17	if MainSICCode >=	3420	&MainSICCode <=	3429
replace fama_french_industry =	17	if MainSICCode >=	3430	&MainSICCode <=	3433
replace fama_french_industry =	17	if MainSICCode >=	3440	&MainSICCode <=	3441
replace fama_french_industry =	17	if MainSICCode >=	3442	&MainSICCode <=	3442
replace fama_french_industry =	17	if MainSICCode >=	3446	&MainSICCode <=	3446
replace fama_french_industry =	17	if MainSICCode >=	3448	&MainSICCode <=	3448
replace fama_french_industry =	17	if MainSICCode >=	3449	&MainSICCode <=	3449
replace fama_french_industry =	17	if MainSICCode >=	3450	&MainSICCode <=	3451
replace fama_french_industry =	17	if MainSICCode >=	3452	&MainSICCode <=	3452
replace fama_french_industry =	17	if MainSICCode >=	3490	&MainSICCode <=	3499
replace fama_french_industry =	17	if MainSICCode >=	3996	&MainSICCode <=	3996
replace fama_french_industry =	18	if MainSICCode >=	1500	&MainSICCode <=	1511
replace fama_french_industry =	18	if MainSICCode >=	1520	&MainSICCode <=	1529
replace fama_french_industry =	18	if MainSICCode >=	1530	&MainSICCode <=	1539
replace fama_french_industry =	18	if MainSICCode >=	1540	&MainSICCode <=	1549
replace fama_french_industry =	18	if MainSICCode >=	1600	&MainSICCode <=	1699
replace fama_french_industry =	18	if MainSICCode >=	1700	&MainSICCode <=	1799
replace fama_french_industry =	19	if MainSICCode >=	3300	&MainSICCode <=	3300
replace fama_french_industry =	19	if MainSICCode >=	3310	&MainSICCode <=	3317
replace fama_french_industry =	19	if MainSICCode >=	3320	&MainSICCode <=	3325
replace fama_french_industry =	19	if MainSICCode >=	3330	&MainSICCode <=	3339
replace fama_french_industry =	19	if MainSICCode >=	3340	&MainSICCode <=	3341
replace fama_french_industry =	19	if MainSICCode >=	3350	&MainSICCode <=	3357
replace fama_french_industry =	19	if MainSICCode >=	3360	&MainSICCode <=	3369
replace fama_french_industry =	19	if MainSICCode >=	3370	&MainSICCode <=	3379
replace fama_french_industry =	19	if MainSICCode >=	3390	&MainSICCode <=	3399
replace fama_french_industry =	20	if MainSICCode >=	3400	&MainSICCode <=	3400
replace fama_french_industry =	20	if MainSICCode >=	3443	&MainSICCode <=	3443
replace fama_french_industry =	20	if MainSICCode >=	3444	&MainSICCode <=	3444
replace fama_french_industry =	20	if MainSICCode >=	3460	&MainSICCode <=	3469
replace fama_french_industry =	20	if MainSICCode >=	3470	&MainSICCode <=	3479
replace fama_french_industry =	21	if MainSICCode >=	3510	&MainSICCode <=	3519
replace fama_french_industry =	21	if MainSICCode >=	3520	&MainSICCode <=	3529
replace fama_french_industry =	21	if MainSICCode >=	3530	&MainSICCode <=	3530
replace fama_french_industry =	21	if MainSICCode >=	3531	&MainSICCode <=	3531
replace fama_french_industry =	21	if MainSICCode >=	3532	&MainSICCode <=	3532
replace fama_french_industry =	21	if MainSICCode >=	3533	&MainSICCode <=	3533
replace fama_french_industry =	21	if MainSICCode >=	3534	&MainSICCode <=	3534
replace fama_french_industry =	21	if MainSICCode >=	3535	&MainSICCode <=	3535
replace fama_french_industry =	21	if MainSICCode >=	3536	&MainSICCode <=	3536
replace fama_french_industry =	21	if MainSICCode >=	3538	&MainSICCode <=	3538
replace fama_french_industry =	21	if MainSICCode >=	3540	&MainSICCode <=	3549
replace fama_french_industry =	21	if MainSICCode >=	3550	&MainSICCode <=	3559
replace fama_french_industry =	21	if MainSICCode >=	3560	&MainSICCode <=	3569
replace fama_french_industry =	21	if MainSICCode >=	3580	&MainSICCode <=	3580
replace fama_french_industry =	21	if MainSICCode >=	3581	&MainSICCode <=	3581
replace fama_french_industry =	21	if MainSICCode >=	3582	&MainSICCode <=	3582
replace fama_french_industry =	21	if MainSICCode >=	3585	&MainSICCode <=	3585
replace fama_french_industry =	21	if MainSICCode >=	3586	&MainSICCode <=	3586
replace fama_french_industry =	21	if MainSICCode >=	3589	&MainSICCode <=	3589
replace fama_french_industry =	21	if MainSICCode >=	3590	&MainSICCode <=	3599
replace fama_french_industry =	22	if MainSICCode >=	3600	&MainSICCode <=	3600
replace fama_french_industry =	22	if MainSICCode >=	3610	&MainSICCode <=	3613
replace fama_french_industry =	22	if MainSICCode >=	3620	&MainSICCode <=	3621
replace fama_french_industry =	22	if MainSICCode >=	3623	&MainSICCode <=	3629
replace fama_french_industry =	22	if MainSICCode >=	3640	&MainSICCode <=	3644
replace fama_french_industry =	22	if MainSICCode >=	3645	&MainSICCode <=	3645
replace fama_french_industry =	22	if MainSICCode >=	3646	&MainSICCode <=	3646
replace fama_french_industry =	22	if MainSICCode >=	3648	&MainSICCode <=	3649
replace fama_french_industry =	22	if MainSICCode >=	3660	&MainSICCode <=	3660
replace fama_french_industry =	22	if MainSICCode >=	3690	&MainSICCode <=	3690
replace fama_french_industry =	22	if MainSICCode >=	3691	&MainSICCode <=	3692
replace fama_french_industry =	22	if MainSICCode >=	3699	&MainSICCode <=	3699
replace fama_french_industry =	23	if MainSICCode >=	2296	&MainSICCode <=	2296
replace fama_french_industry =	23	if MainSICCode >=	2396	&MainSICCode <=	2396
replace fama_french_industry =	23	if MainSICCode >=	3010	&MainSICCode <=	3011
replace fama_french_industry =	23	if MainSICCode >=	3537	&MainSICCode <=	3537
replace fama_french_industry =	23	if MainSICCode >=	3647	&MainSICCode <=	3647
replace fama_french_industry =	23	if MainSICCode >=	3694	&MainSICCode <=	3694
replace fama_french_industry =	23	if MainSICCode >=	3700	&MainSICCode <=	3700
replace fama_french_industry =	23	if MainSICCode >=	3710	&MainSICCode <=	3710
replace fama_french_industry =	23	if MainSICCode >=	3711	&MainSICCode <=	3711
replace fama_french_industry =	23	if MainSICCode >=	3713	&MainSICCode <=	3713
replace fama_french_industry =	23	if MainSICCode >=	3714	&MainSICCode <=	3714
replace fama_french_industry =	23	if MainSICCode >=	3715	&MainSICCode <=	3715
replace fama_french_industry =	23	if MainSICCode >=	3716	&MainSICCode <=	3716
replace fama_french_industry =	23	if MainSICCode >=	3792	&MainSICCode <=	3792
replace fama_french_industry =	23	if MainSICCode >=	3790	&MainSICCode <=	3791
replace fama_french_industry =	23	if MainSICCode >=	3799	&MainSICCode <=	3799
replace fama_french_industry =	24	if MainSICCode >=	3720	&MainSICCode <=	3720
replace fama_french_industry =	24	if MainSICCode >=	3721	&MainSICCode <=	3721
replace fama_french_industry =	24	if MainSICCode >=	3723	&MainSICCode <=	3724
replace fama_french_industry =	24	if MainSICCode >=	3725	&MainSICCode <=	3725
replace fama_french_industry =	24	if MainSICCode >=	3728	&MainSICCode <=	3729
replace fama_french_industry =	25	if MainSICCode >=	3730	&MainSICCode <=	3731
replace fama_french_industry =	25	if MainSICCode >=	3740	&MainSICCode <=	3743
replace fama_french_industry =	26	if MainSICCode >=	3760	&MainSICCode <=	3769
replace fama_french_industry =	26	if MainSICCode >=	3795	&MainSICCode <=	3795
replace fama_french_industry =	26	if MainSICCode >=	3480	&MainSICCode <=	3489
replace fama_french_industry =	27	if MainSICCode >=	1040	&MainSICCode <=	1049
replace fama_french_industry =	28	if MainSICCode >=	1000	&MainSICCode <=	1009
replace fama_french_industry =	28	if MainSICCode >=	1010	&MainSICCode <=	1019
replace fama_french_industry =	28	if MainSICCode >=	1020	&MainSICCode <=	1029
replace fama_french_industry =	28	if MainSICCode >=	1030	&MainSICCode <=	1039
replace fama_french_industry =	28	if MainSICCode >=	1050	&MainSICCode <=	1059
replace fama_french_industry =	28	if MainSICCode >=	1060	&MainSICCode <=	1069
replace fama_french_industry =	28	if MainSICCode >=	1070	&MainSICCode <=	1079
replace fama_french_industry =	28	if MainSICCode >=	1080	&MainSICCode <=	1089
replace fama_french_industry =	28	if MainSICCode >=	1090	&MainSICCode <=	1099
replace fama_french_industry =	28	if MainSICCode >=	1100	&MainSICCode <=	1119
replace fama_french_industry =	28	if MainSICCode >=	1400	&MainSICCode <=	1499
replace fama_french_industry =	29	if MainSICCode >=	1200	&MainSICCode <=	1299
replace fama_french_industry =	30	if MainSICCode >=	1300	&MainSICCode <=	1300
replace fama_french_industry =	30	if MainSICCode >=	1310	&MainSICCode <=	1319
replace fama_french_industry =	30	if MainSICCode >=	1320	&MainSICCode <=	1329
replace fama_french_industry =	30	if MainSICCode >=	1330	&MainSICCode <=	1339
replace fama_french_industry =	30	if MainSICCode >=	1370	&MainSICCode <=	1379
replace fama_french_industry =	30	if MainSICCode >=	1380	&MainSICCode <=	1380
replace fama_french_industry =	30	if MainSICCode >=	1381	&MainSICCode <=	1381
replace fama_french_industry =	30	if MainSICCode >=	1382	&MainSICCode <=	1382
replace fama_french_industry =	30	if MainSICCode >=	1389	&MainSICCode <=	1389
replace fama_french_industry =	30	if MainSICCode >=	2900	&MainSICCode <=	2912
replace fama_french_industry =	30	if MainSICCode >=	2990	&MainSICCode <=	2999
replace fama_french_industry =	31	if MainSICCode >=	4900	&MainSICCode <=	4900
replace fama_french_industry =	31	if MainSICCode >=	4910	&MainSICCode <=	4911
replace fama_french_industry =	31	if MainSICCode >=	4920	&MainSICCode <=	4922
replace fama_french_industry =	31	if MainSICCode >=	4923	&MainSICCode <=	4923
replace fama_french_industry =	31	if MainSICCode >=	4924	&MainSICCode <=	4925
replace fama_french_industry =	31	if MainSICCode >=	4930	&MainSICCode <=	4931
replace fama_french_industry =	31	if MainSICCode >=	4932	&MainSICCode <=	4932
replace fama_french_industry =	31	if MainSICCode >=	4939	&MainSICCode <=	4939
replace fama_french_industry =	31	if MainSICCode >=	4940	&MainSICCode <=	4942
replace fama_french_industry =	32	if MainSICCode >=	4800	&MainSICCode <=	4800
replace fama_french_industry =	32	if MainSICCode >=	4810	&MainSICCode <=	4813
replace fama_french_industry =	32	if MainSICCode >=	4820	&MainSICCode <=	4822
replace fama_french_industry =	32	if MainSICCode >=	4830	&MainSICCode <=	4839
replace fama_french_industry =	32	if MainSICCode >=	4840	&MainSICCode <=	4841
replace fama_french_industry =	32	if MainSICCode >=	4880	&MainSICCode <=	4889
replace fama_french_industry =	32	if MainSICCode >=	4890	&MainSICCode <=	4890
replace fama_french_industry =	32	if MainSICCode >=	4891	&MainSICCode <=	4891
replace fama_french_industry =	32	if MainSICCode >=	4892	&MainSICCode <=	4892
replace fama_french_industry =	32	if MainSICCode >=	4899	&MainSICCode <=	4899
replace fama_french_industry =	33	if MainSICCode >=	7020	&MainSICCode <=	7021
replace fama_french_industry =	33	if MainSICCode >=	7030	&MainSICCode <=	7033
replace fama_french_industry =	33	if MainSICCode >=	7200	&MainSICCode <=	7200
replace fama_french_industry =	33	if MainSICCode >=	7210	&MainSICCode <=	7212
replace fama_french_industry =	33	if MainSICCode >=	7214	&MainSICCode <=	7214
replace fama_french_industry =	33	if MainSICCode >=	7215	&MainSICCode <=	7216
replace fama_french_industry =	33	if MainSICCode >=	7217	&MainSICCode <=	7217
replace fama_french_industry =	33	if MainSICCode >=	7219	&MainSICCode <=	7219
replace fama_french_industry =	33	if MainSICCode >=	7220	&MainSICCode <=	7221
replace fama_french_industry =	33	if MainSICCode >=	7230	&MainSICCode <=	7231
replace fama_french_industry =	33	if MainSICCode >=	7240	&MainSICCode <=	7241
replace fama_french_industry =	33	if MainSICCode >=	7250	&MainSICCode <=	7251
replace fama_french_industry =	33	if MainSICCode >=	7260	&MainSICCode <=	7269
replace fama_french_industry =	33	if MainSICCode >=	7270	&MainSICCode <=	7290
replace fama_french_industry =	33	if MainSICCode >=	7291	&MainSICCode <=	7291
replace fama_french_industry =	33	if MainSICCode >=	7292	&MainSICCode <=	7299
replace fama_french_industry =	33	if MainSICCode >=	7395	&MainSICCode <=	7395
replace fama_french_industry =	33	if MainSICCode >=	7500	&MainSICCode <=	7500
replace fama_french_industry =	33	if MainSICCode >=	7520	&MainSICCode <=	7529
replace fama_french_industry =	33	if MainSICCode >=	7530	&MainSICCode <=	7539
replace fama_french_industry =	33	if MainSICCode >=	7540	&MainSICCode <=	7549
replace fama_french_industry =	33	if MainSICCode >=	7600	&MainSICCode <=	7600
replace fama_french_industry =	33	if MainSICCode >=	7620	&MainSICCode <=	7620
replace fama_french_industry =	33	if MainSICCode >=	7622	&MainSICCode <=	7622
replace fama_french_industry =	33	if MainSICCode >=	7623	&MainSICCode <=	7623
replace fama_french_industry =	33	if MainSICCode >=	7629	&MainSICCode <=	7629
replace fama_french_industry =	33	if MainSICCode >=	7630	&MainSICCode <=	7631
replace fama_french_industry =	33	if MainSICCode >=	7640	&MainSICCode <=	7641
replace fama_french_industry =	33	if MainSICCode >=	7690	&MainSICCode <=	7699
replace fama_french_industry =	33	if MainSICCode >=	8100	&MainSICCode <=	8199
replace fama_french_industry =	33	if MainSICCode >=	8200	&MainSICCode <=	8299
replace fama_french_industry =	33	if MainSICCode >=	8300	&MainSICCode <=	8399
replace fama_french_industry =	33	if MainSICCode >=	8400	&MainSICCode <=	8499
replace fama_french_industry =	33	if MainSICCode >=	8600	&MainSICCode <=	8699
replace fama_french_industry =	33	if MainSICCode >=	8800	&MainSICCode <=	8899
replace fama_french_industry =	33	if MainSICCode >=	7510	&MainSICCode <=	7515
replace fama_french_industry =	34	if MainSICCode >=	2750	&MainSICCode <=	2759
replace fama_french_industry =	34	if MainSICCode >=	3993	&MainSICCode <=	3993
replace fama_french_industry =	34	if MainSICCode >=	7218	&MainSICCode <=	7218
replace fama_french_industry =	34	if MainSICCode >=	7300	&MainSICCode <=	7300
replace fama_french_industry =	34	if MainSICCode >=	7310	&MainSICCode <=	7319
replace fama_french_industry =	34	if MainSICCode >=	7320	&MainSICCode <=	7329
replace fama_french_industry =	34	if MainSICCode >=	7330	&MainSICCode <=	7339
replace fama_french_industry =	34	if MainSICCode >=	7340	&MainSICCode <=	7342
replace fama_french_industry =	34	if MainSICCode >=	7349	&MainSICCode <=	7349
replace fama_french_industry =	34	if MainSICCode >=	7350	&MainSICCode <=	7351
replace fama_french_industry =	34	if MainSICCode >=	7352	&MainSICCode <=	7352
replace fama_french_industry =	34	if MainSICCode >=	7353	&MainSICCode <=	7353
replace fama_french_industry =	34	if MainSICCode >=	7359	&MainSICCode <=	7359
replace fama_french_industry =	34	if MainSICCode >=	7360	&MainSICCode <=	7369
replace fama_french_industry =	34	if MainSICCode >=	7370	&MainSICCode <=	7372
replace fama_french_industry =	34	if MainSICCode >=	7374	&MainSICCode <=	7374
replace fama_french_industry =	34	if MainSICCode >=	7375	&MainSICCode <=	7375
replace fama_french_industry =	34	if MainSICCode >=	7376	&MainSICCode <=	7376
replace fama_french_industry =	34	if MainSICCode >=	7377	&MainSICCode <=	7377
replace fama_french_industry =	34	if MainSICCode >=	7378	&MainSICCode <=	7378
replace fama_french_industry =	34	if MainSICCode >=	7379	&MainSICCode <=	7379
replace fama_french_industry =	34	if MainSICCode >=	7380	&MainSICCode <=	7380
replace fama_french_industry =	34	if MainSICCode >=	7381	&MainSICCode <=	7382
replace fama_french_industry =	34	if MainSICCode >=	7383	&MainSICCode <=	7383
replace fama_french_industry =	34	if MainSICCode >=	7384	&MainSICCode <=	7384
replace fama_french_industry =	34	if MainSICCode >=	7385	&MainSICCode <=	7385
replace fama_french_industry =	34	if MainSICCode >=	7389	&MainSICCode <=	7390
replace fama_french_industry =	34	if MainSICCode >=	7391	&MainSICCode <=	7391
replace fama_french_industry =	34	if MainSICCode >=	7392	&MainSICCode <=	7392
replace fama_french_industry =	34	if MainSICCode >=	7393	&MainSICCode <=	7393
replace fama_french_industry =	34	if MainSICCode >=	7394	&MainSICCode <=	7394
replace fama_french_industry =	34	if MainSICCode >=	7396	&MainSICCode <=	7396
replace fama_french_industry =	34	if MainSICCode >=	7397	&MainSICCode <=	7397
replace fama_french_industry =	34	if MainSICCode >=	7399	&MainSICCode <=	7399
replace fama_french_industry =	34	if MainSICCode >=	7519	&MainSICCode <=	7519
replace fama_french_industry =	34	if MainSICCode >=	8700	&MainSICCode <=	8700
replace fama_french_industry =	34	if MainSICCode >=	8710	&MainSICCode <=	8713
replace fama_french_industry =	34	if MainSICCode >=	8720	&MainSICCode <=	8721
replace fama_french_industry =	34	if MainSICCode >=	8730	&MainSICCode <=	8734
replace fama_french_industry =	34	if MainSICCode >=	8740	&MainSICCode <=	8748
replace fama_french_industry =	34	if MainSICCode >=	8900	&MainSICCode <=	8910
replace fama_french_industry =	34	if MainSICCode >=	8911	&MainSICCode <=	8911
replace fama_french_industry =	34	if MainSICCode >=	8920	&MainSICCode <=	8999
replace fama_french_industry =	34	if MainSICCode >=	4220	&MainSICCode <=	4229
replace fama_french_industry =	35	if MainSICCode >=	3570	&MainSICCode <=	3579
replace fama_french_industry =	35	if MainSICCode >=	3680	&MainSICCode <=	3680
replace fama_french_industry =	35	if MainSICCode >=	3681	&MainSICCode <=	3681
replace fama_french_industry =	35	if MainSICCode >=	3682	&MainSICCode <=	3682
replace fama_french_industry =	35	if MainSICCode >=	3683	&MainSICCode <=	3683
replace fama_french_industry =	35	if MainSICCode >=	3684	&MainSICCode <=	3684
replace fama_french_industry =	35	if MainSICCode >=	3685	&MainSICCode <=	3685
replace fama_french_industry =	35	if MainSICCode >=	3686	&MainSICCode <=	3686
replace fama_french_industry =	35	if MainSICCode >=	3687	&MainSICCode <=	3687
replace fama_french_industry =	35	if MainSICCode >=	3688	&MainSICCode <=	3688
replace fama_french_industry =	35	if MainSICCode >=	3689	&MainSICCode <=	3689
replace fama_french_industry =	35	if MainSICCode >=	3695	&MainSICCode <=	3695
replace fama_french_industry =	35	if MainSICCode >=	7373	&MainSICCode <=	7373
replace fama_french_industry =	36	if MainSICCode >=	3622	&MainSICCode <=	3622
replace fama_french_industry =	36	if MainSICCode >=	3661	&MainSICCode <=	3661
replace fama_french_industry =	36	if MainSICCode >=	3662	&MainSICCode <=	3662
replace fama_french_industry =	36	if MainSICCode >=	3663	&MainSICCode <=	3663
replace fama_french_industry =	36	if MainSICCode >=	3664	&MainSICCode <=	3664
replace fama_french_industry =	36	if MainSICCode >=	3665	&MainSICCode <=	3665
replace fama_french_industry =	36	if MainSICCode >=	3666	&MainSICCode <=	3666
replace fama_french_industry =	36	if MainSICCode >=	3669	&MainSICCode <=	3669
replace fama_french_industry =	36	if MainSICCode >=	3670	&MainSICCode <=	3679
replace fama_french_industry =	36	if MainSICCode >=	3810	&MainSICCode <=	3810
replace fama_french_industry =	36	if MainSICCode >=	3812	&MainSICCode <=	3812
replace fama_french_industry =	37	if MainSICCode >=	3811	&MainSICCode <=	3811
replace fama_french_industry =	37	if MainSICCode >=	3820	&MainSICCode <=	3820
replace fama_french_industry =	37	if MainSICCode >=	3821	&MainSICCode <=	3821
replace fama_french_industry =	37	if MainSICCode >=	3822	&MainSICCode <=	3822
replace fama_french_industry =	37	if MainSICCode >=	3823	&MainSICCode <=	3823
replace fama_french_industry =	37	if MainSICCode >=	3824	&MainSICCode <=	3824
replace fama_french_industry =	37	if MainSICCode >=	3825	&MainSICCode <=	3825
replace fama_french_industry =	37	if MainSICCode >=	3826	&MainSICCode <=	3826
replace fama_french_industry =	37	if MainSICCode >=	3827	&MainSICCode <=	3827
replace fama_french_industry =	37	if MainSICCode >=	3829	&MainSICCode <=	3829
replace fama_french_industry =	37	if MainSICCode >=	3830	&MainSICCode <=	3839
replace fama_french_industry =	38	if MainSICCode >=	2520	&MainSICCode <=	2549
replace fama_french_industry =	38	if MainSICCode >=	2600	&MainSICCode <=	2639
replace fama_french_industry =	38	if MainSICCode >=	2670	&MainSICCode <=	2699
replace fama_french_industry =	38	if MainSICCode >=	2760	&MainSICCode <=	2761
replace fama_french_industry =	38	if MainSICCode >=	3950	&MainSICCode <=	3955
replace fama_french_industry =	39	if MainSICCode >=	2440	&MainSICCode <=	2449
replace fama_french_industry =	39	if MainSICCode >=	2640	&MainSICCode <=	2659
replace fama_french_industry =	39	if MainSICCode >=	3220	&MainSICCode <=	3221
replace fama_french_industry =	39	if MainSICCode >=	3410	&MainSICCode <=	3412
replace fama_french_industry =	40	if MainSICCode >=	4000	&MainSICCode <=	4013
replace fama_french_industry =	40	if MainSICCode >=	4040	&MainSICCode <=	4049
replace fama_french_industry =	40	if MainSICCode >=	4100	&MainSICCode <=	4100
replace fama_french_industry =	40	if MainSICCode >=	4110	&MainSICCode <=	4119
replace fama_french_industry =	40	if MainSICCode >=	4120	&MainSICCode <=	4121
replace fama_french_industry =	40	if MainSICCode >=	4130	&MainSICCode <=	4131
replace fama_french_industry =	40	if MainSICCode >=	4140	&MainSICCode <=	4142
replace fama_french_industry =	40	if MainSICCode >=	4150	&MainSICCode <=	4151
replace fama_french_industry =	40	if MainSICCode >=	4170	&MainSICCode <=	4173
replace fama_french_industry =	40	if MainSICCode >=	4190	&MainSICCode <=	4199
replace fama_french_industry =	40	if MainSICCode >=	4200	&MainSICCode <=	4200
replace fama_french_industry =	40	if MainSICCode >=	4210	&MainSICCode <=	4219
replace fama_french_industry =	40	if MainSICCode >=	4230	&MainSICCode <=	4231
replace fama_french_industry =	40	if MainSICCode >=	4240	&MainSICCode <=	4249
replace fama_french_industry =	40	if MainSICCode >=	4400	&MainSICCode <=	4499
replace fama_french_industry =	40	if MainSICCode >=	4500	&MainSICCode <=	4599
replace fama_french_industry =	40	if MainSICCode >=	4600	&MainSICCode <=	4699
replace fama_french_industry =	40	if MainSICCode >=	4700	&MainSICCode <=	4700
replace fama_french_industry =	40	if MainSICCode >=	4710	&MainSICCode <=	4712
replace fama_french_industry =	40	if MainSICCode >=	4720	&MainSICCode <=	4729
replace fama_french_industry =	40	if MainSICCode >=	4730	&MainSICCode <=	4739
replace fama_french_industry =	40	if MainSICCode >=	4740	&MainSICCode <=	4749
replace fama_french_industry =	40	if MainSICCode >=	4780	&MainSICCode <=	4780
replace fama_french_industry =	40	if MainSICCode >=	4782	&MainSICCode <=	4782
replace fama_french_industry =	40	if MainSICCode >=	4783	&MainSICCode <=	4783
replace fama_french_industry =	40	if MainSICCode >=	4784	&MainSICCode <=	4784
replace fama_french_industry =	40	if MainSICCode >=	4785	&MainSICCode <=	4785
replace fama_french_industry =	40	if MainSICCode >=	4789	&MainSICCode <=	4789
replace fama_french_industry =	41	if MainSICCode >=	5000	&MainSICCode <=	5000
replace fama_french_industry =	41	if MainSICCode >=	5010	&MainSICCode <=	5015
replace fama_french_industry =	41	if MainSICCode >=	5020	&MainSICCode <=	5023
replace fama_french_industry =	41	if MainSICCode >=	5030	&MainSICCode <=	5039
replace fama_french_industry =	41	if MainSICCode >=	5040	&MainSICCode <=	5042
replace fama_french_industry =	41	if MainSICCode >=	5043	&MainSICCode <=	5043
replace fama_french_industry =	41	if MainSICCode >=	5044	&MainSICCode <=	5044
replace fama_french_industry =	41	if MainSICCode >=	5045	&MainSICCode <=	5045
replace fama_french_industry =	41	if MainSICCode >=	5046	&MainSICCode <=	5046
replace fama_french_industry =	41	if MainSICCode >=	5047	&MainSICCode <=	5047
replace fama_french_industry =	41	if MainSICCode >=	5048	&MainSICCode <=	5048
replace fama_french_industry =	41	if MainSICCode >=	5049	&MainSICCode <=	5049
replace fama_french_industry =	41	if MainSICCode >=	5050	&MainSICCode <=	5059
replace fama_french_industry =	41	if MainSICCode >=	5060	&MainSICCode <=	5060
replace fama_french_industry =	41	if MainSICCode >=	5063	&MainSICCode <=	5063
replace fama_french_industry =	41	if MainSICCode >=	5064	&MainSICCode <=	5064
replace fama_french_industry =	41	if MainSICCode >=	5065	&MainSICCode <=	5065
replace fama_french_industry =	41	if MainSICCode >=	5070	&MainSICCode <=	5078
replace fama_french_industry =	41	if MainSICCode >=	5080	&MainSICCode <=	5080
replace fama_french_industry =	41	if MainSICCode >=	5081	&MainSICCode <=	5081
replace fama_french_industry =	41	if MainSICCode >=	5082	&MainSICCode <=	5082
replace fama_french_industry =	41	if MainSICCode >=	5083	&MainSICCode <=	5083
replace fama_french_industry =	41	if MainSICCode >=	5084	&MainSICCode <=	5084
replace fama_french_industry =	41	if MainSICCode >=	5085	&MainSICCode <=	5085
replace fama_french_industry =	41	if MainSICCode >=	5086	&MainSICCode <=	5087
replace fama_french_industry =	41	if MainSICCode >=	5088	&MainSICCode <=	5088
replace fama_french_industry =	41	if MainSICCode >=	5090	&MainSICCode <=	5090
replace fama_french_industry =	41	if MainSICCode >=	5091	&MainSICCode <=	5092
replace fama_french_industry =	41	if MainSICCode >=	5093	&MainSICCode <=	5093
replace fama_french_industry =	41	if MainSICCode >=	5094	&MainSICCode <=	5094
replace fama_french_industry =	41	if MainSICCode >=	5099	&MainSICCode <=	5099
replace fama_french_industry =	41	if MainSICCode >=	5100	&MainSICCode <=	5100
replace fama_french_industry =	41	if MainSICCode >=	5110	&MainSICCode <=	5113
replace fama_french_industry =	41	if MainSICCode >=	5120	&MainSICCode <=	5122
replace fama_french_industry =	41	if MainSICCode >=	5130	&MainSICCode <=	5139
replace fama_french_industry =	41	if MainSICCode >=	5140	&MainSICCode <=	5149
replace fama_french_industry =	41	if MainSICCode >=	5150	&MainSICCode <=	5159
replace fama_french_industry =	41	if MainSICCode >=	5160	&MainSICCode <=	5169
replace fama_french_industry =	41	if MainSICCode >=	5170	&MainSICCode <=	5172
replace fama_french_industry =	41	if MainSICCode >=	5180	&MainSICCode <=	5182
replace fama_french_industry =	41	if MainSICCode >=	5190	&MainSICCode <=	5199
replace fama_french_industry =	42	if MainSICCode >=	5200	&MainSICCode <=	5200
replace fama_french_industry =	42	if MainSICCode >=	5210	&MainSICCode <=	5219
replace fama_french_industry =	42	if MainSICCode >=	5220	&MainSICCode <=	5229
replace fama_french_industry =	42	if MainSICCode >=	5230	&MainSICCode <=	5231
replace fama_french_industry =	42	if MainSICCode >=	5250	&MainSICCode <=	5251
replace fama_french_industry =	42	if MainSICCode >=	5260	&MainSICCode <=	5261
replace fama_french_industry =	42	if MainSICCode >=	5270	&MainSICCode <=	5271
replace fama_french_industry =	42	if MainSICCode >=	5300	&MainSICCode <=	5300
replace fama_french_industry =	42	if MainSICCode >=	5310	&MainSICCode <=	5311
replace fama_french_industry =	42	if MainSICCode >=	5320	&MainSICCode <=	5320
replace fama_french_industry =	42	if MainSICCode >=	5330	&MainSICCode <=	5331
replace fama_french_industry =	42	if MainSICCode >=	5334	&MainSICCode <=	5334
replace fama_french_industry =	42	if MainSICCode >=	5340	&MainSICCode <=	5349
replace fama_french_industry =	42	if MainSICCode >=	5390	&MainSICCode <=	5399
replace fama_french_industry =	42	if MainSICCode >=	5400	&MainSICCode <=	5400
replace fama_french_industry =	42	if MainSICCode >=	5410	&MainSICCode <=	5411
replace fama_french_industry =	42	if MainSICCode >=	5412	&MainSICCode <=	5412
replace fama_french_industry =	42	if MainSICCode >=	5420	&MainSICCode <=	5429
replace fama_french_industry =	42	if MainSICCode >=	5430	&MainSICCode <=	5439
replace fama_french_industry =	42	if MainSICCode >=	5440	&MainSICCode <=	5449
replace fama_french_industry =	42	if MainSICCode >=	5450	&MainSICCode <=	5459
replace fama_french_industry =	42	if MainSICCode >=	5460	&MainSICCode <=	5469
replace fama_french_industry =	42	if MainSICCode >=	5490	&MainSICCode <=	5499
replace fama_french_industry =	42	if MainSICCode >=	5500	&MainSICCode <=	5500
replace fama_french_industry =	42	if MainSICCode >=	5510	&MainSICCode <=	5529
replace fama_french_industry =	42	if MainSICCode >=	5530	&MainSICCode <=	5539
replace fama_french_industry =	42	if MainSICCode >=	5540	&MainSICCode <=	5549
replace fama_french_industry =	42	if MainSICCode >=	5550	&MainSICCode <=	5559
replace fama_french_industry =	42	if MainSICCode >=	5560	&MainSICCode <=	5569
replace fama_french_industry =	42	if MainSICCode >=	5570	&MainSICCode <=	5579
replace fama_french_industry =	42	if MainSICCode >=	5590	&MainSICCode <=	5599
replace fama_french_industry =	42	if MainSICCode >=	5600	&MainSICCode <=	5699
replace fama_french_industry =	42	if MainSICCode >=	5700	&MainSICCode <=	5700
replace fama_french_industry =	42	if MainSICCode >=	5710	&MainSICCode <=	5719
replace fama_french_industry =	42	if MainSICCode >=	5720	&MainSICCode <=	5722
replace fama_french_industry =	42	if MainSICCode >=	5730	&MainSICCode <=	5733
replace fama_french_industry =	42	if MainSICCode >=	5734	&MainSICCode <=	5734
replace fama_french_industry =	42	if MainSICCode >=	5735	&MainSICCode <=	5735
replace fama_french_industry =	42	if MainSICCode >=	5736	&MainSICCode <=	5736
replace fama_french_industry =	42	if MainSICCode >=	5750	&MainSICCode <=	5799
replace fama_french_industry =	42	if MainSICCode >=	5900	&MainSICCode <=	5900
replace fama_french_industry =	42	if MainSICCode >=	5910	&MainSICCode <=	5912
replace fama_french_industry =	42	if MainSICCode >=	5920	&MainSICCode <=	5929
replace fama_french_industry =	42	if MainSICCode >=	5930	&MainSICCode <=	5932
replace fama_french_industry =	42	if MainSICCode >=	5940	&MainSICCode <=	5940
replace fama_french_industry =	42	if MainSICCode >=	5941	&MainSICCode <=	5941
replace fama_french_industry =	42	if MainSICCode >=	5942	&MainSICCode <=	5942
replace fama_french_industry =	42	if MainSICCode >=	5943	&MainSICCode <=	5943
replace fama_french_industry =	42	if MainSICCode >=	5944	&MainSICCode <=	5944
replace fama_french_industry =	42	if MainSICCode >=	5945	&MainSICCode <=	5945
replace fama_french_industry =	42	if MainSICCode >=	5946	&MainSICCode <=	5946
replace fama_french_industry =	42	if MainSICCode >=	5947	&MainSICCode <=	5947
replace fama_french_industry =	42	if MainSICCode >=	5948	&MainSICCode <=	5948
replace fama_french_industry =	42	if MainSICCode >=	5949	&MainSICCode <=	5949
replace fama_french_industry =	42	if MainSICCode >=	5950	&MainSICCode <=	5959
replace fama_french_industry =	42	if MainSICCode >=	5960	&MainSICCode <=	5969
replace fama_french_industry =	42	if MainSICCode >=	5970	&MainSICCode <=	5979
replace fama_french_industry =	42	if MainSICCode >=	5980	&MainSICCode <=	5989
replace fama_french_industry =	42	if MainSICCode >=	5990	&MainSICCode <=	5990
replace fama_french_industry =	42	if MainSICCode >=	5992	&MainSICCode <=	5992
replace fama_french_industry =	42	if MainSICCode >=	5993	&MainSICCode <=	5993
replace fama_french_industry =	42	if MainSICCode >=	5994	&MainSICCode <=	5994
replace fama_french_industry =	42	if MainSICCode >=	5995	&MainSICCode <=	5995
replace fama_french_industry =	42	if MainSICCode >=	5999	&MainSICCode <=	5999
replace fama_french_industry =	43	if MainSICCode >=	5800	&MainSICCode <=	5819
replace fama_french_industry =	43	if MainSICCode >=	5820	&MainSICCode <=	5829
replace fama_french_industry =	43	if MainSICCode >=	5890	&MainSICCode <=	5899
replace fama_french_industry =	43	if MainSICCode >=	7000	&MainSICCode <=	7000
replace fama_french_industry =	43	if MainSICCode >=	7010	&MainSICCode <=	7019
replace fama_french_industry =	43	if MainSICCode >=	7040	&MainSICCode <=	7049
replace fama_french_industry =	43	if MainSICCode >=	7213	&MainSICCode <=	7213
replace fama_french_industry =	44	if MainSICCode >=	6000	&MainSICCode <=	6000
replace fama_french_industry =	44	if MainSICCode >=	6010	&MainSICCode <=	6019
replace fama_french_industry =	44	if MainSICCode >=	6020	&MainSICCode <=	6020
replace fama_french_industry =	44	if MainSICCode >=	6021	&MainSICCode <=	6021
replace fama_french_industry =	44	if MainSICCode >=	6022	&MainSICCode <=	6022
replace fama_french_industry =	44	if MainSICCode >=	6023	&MainSICCode <=	6024
replace fama_french_industry =	44	if MainSICCode >=	6025	&MainSICCode <=	6025
replace fama_french_industry =	44	if MainSICCode >=	6026	&MainSICCode <=	6026
replace fama_french_industry =	44	if MainSICCode >=	6027	&MainSICCode <=	6027
replace fama_french_industry =	44	if MainSICCode >=	6028	&MainSICCode <=	6029
replace fama_french_industry =	44	if MainSICCode >=	6030	&MainSICCode <=	6036
replace fama_french_industry =	44	if MainSICCode >=	6040	&MainSICCode <=	6059
replace fama_french_industry =	44	if MainSICCode >=	6060	&MainSICCode <=	6062
replace fama_french_industry =	44	if MainSICCode >=	6080	&MainSICCode <=	6082
replace fama_french_industry =	44	if MainSICCode >=	6090	&MainSICCode <=	6099
replace fama_french_industry =	44	if MainSICCode >=	6100	&MainSICCode <=	6100
replace fama_french_industry =	44	if MainSICCode >=	6110	&MainSICCode <=	6111
replace fama_french_industry =	44	if MainSICCode >=	6112	&MainSICCode <=	6113
replace fama_french_industry =	44	if MainSICCode >=	6120	&MainSICCode <=	6129
replace fama_french_industry =	44	if MainSICCode >=	6130	&MainSICCode <=	6139
replace fama_french_industry =	44	if MainSICCode >=	6140	&MainSICCode <=	6149
replace fama_french_industry =	44	if MainSICCode >=	6150	&MainSICCode <=	6159
replace fama_french_industry =	44	if MainSICCode >=	6160	&MainSICCode <=	6169
replace fama_french_industry =	44	if MainSICCode >=	6170	&MainSICCode <=	6179
replace fama_french_industry =	44	if MainSICCode >=	6190	&MainSICCode <=	6199
replace fama_french_industry =	45	if MainSICCode >=	6300	&MainSICCode <=	6300
replace fama_french_industry =	45	if MainSICCode >=	6310	&MainSICCode <=	6319
replace fama_french_industry =	45	if MainSICCode >=	6320	&MainSICCode <=	6329
replace fama_french_industry =	45	if MainSICCode >=	6330	&MainSICCode <=	6331
replace fama_french_industry =	45	if MainSICCode >=	6350	&MainSICCode <=	6351
replace fama_french_industry =	45	if MainSICCode >=	6360	&MainSICCode <=	6361
replace fama_french_industry =	45	if MainSICCode >=	6370	&MainSICCode <=	6379
replace fama_french_industry =	45	if MainSICCode >=	6390	&MainSICCode <=	6399
replace fama_french_industry =	45	if MainSICCode >=	6400	&MainSICCode <=	6411
replace fama_french_industry =	46	if MainSICCode >=	6500	&MainSICCode <=	6500
replace fama_french_industry =	46	if MainSICCode >=	6510	&MainSICCode <=	6510
replace fama_french_industry =	46	if MainSICCode >=	6512	&MainSICCode <=	6512
replace fama_french_industry =	46	if MainSICCode >=	6513	&MainSICCode <=	6513
replace fama_french_industry =	46	if MainSICCode >=	6514	&MainSICCode <=	6514
replace fama_french_industry =	46	if MainSICCode >=	6515	&MainSICCode <=	6515
replace fama_french_industry =	46	if MainSICCode >=	6517	&MainSICCode <=	6519
replace fama_french_industry =	46	if MainSICCode >=	6520	&MainSICCode <=	6529
replace fama_french_industry =	46	if MainSICCode >=	6530	&MainSICCode <=	6531
replace fama_french_industry =	46	if MainSICCode >=	6532	&MainSICCode <=	6532
replace fama_french_industry =	46	if MainSICCode >=	6540	&MainSICCode <=	6541
replace fama_french_industry =	46	if MainSICCode >=	6550	&MainSICCode <=	6553
replace fama_french_industry =	46	if MainSICCode >=	6590	&MainSICCode <=	6599
replace fama_french_industry =	46	if MainSICCode >=	6610	&MainSICCode <=	6611
replace fama_french_industry =	47	if MainSICCode >=	6200	&MainSICCode <=	6299
replace fama_french_industry =	47	if MainSICCode >=	6700	&MainSICCode <=	6700
replace fama_french_industry =	47	if MainSICCode >=	6710	&MainSICCode <=	6719
replace fama_french_industry =	47	if MainSICCode >=	6720	&MainSICCode <=	6722
replace fama_french_industry =	47	if MainSICCode >=	6723	&MainSICCode <=	6723
replace fama_french_industry =	47	if MainSICCode >=	6724	&MainSICCode <=	6724
replace fama_french_industry =	47	if MainSICCode >=	6725	&MainSICCode <=	6725
replace fama_french_industry =	47	if MainSICCode >=	6726	&MainSICCode <=	6726
replace fama_french_industry =	47	if MainSICCode >=	6730	&MainSICCode <=	6733
replace fama_french_industry =	47	if MainSICCode >=	6740	&MainSICCode <=	6779
replace fama_french_industry =	47	if MainSICCode >=	6790	&MainSICCode <=	6791
replace fama_french_industry =	47	if MainSICCode >=	6792	&MainSICCode <=	6792
replace fama_french_industry =	47	if MainSICCode >=	6793	&MainSICCode <=	6793
replace fama_french_industry =	47	if MainSICCode >=	6794	&MainSICCode <=	6794
replace fama_french_industry =	47	if MainSICCode >=	6795	&MainSICCode <=	6795
replace fama_french_industry =	47	if MainSICCode >=	6798	&MainSICCode <=	6798
replace fama_french_industry =	47	if MainSICCode >=	6799	&MainSICCode <=	6799
replace fama_french_industry =	48	if MainSICCode >=	4950	&MainSICCode <=	4959
replace fama_french_industry =	48	if MainSICCode >=	4960	&MainSICCode <=	4961
replace fama_french_industry =	48	if MainSICCode >=	4970	&MainSICCode <=	4971
replace fama_french_industry =	48	if MainSICCode >=	4990	&MainSICCode <=	4991

cap drop logproceeds
replace ProceedsAmtinthisMktm = subinstr(ProceedsAmtinthisMktm,"/","",.)
destring ProceedsAmtinthisMktm,replace
gen logproceeds2 = log(ProceedsAmtinthisMktm)
gen logproceeds = log(ProceedsAmtsumofallMktsm)

label variable logproceeds1 "log IPO Proceeds"
label variable logproceeds2 "log (IPO Proceeds)"


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

save SDC_IBES_market_merged_master_19932017.dta,replace
save "${directory}SDC_IBES_market_merged_master_19932017.dta",replace


