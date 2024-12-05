*****************************************************
* Data Exercise 3
*****************************************************

clear all
set more off

**********************************
* 1. Load and Clean PWT Data
**********************************
use pwt1001.dta, clear

* Keep only 1970-1999
keep if year >= 1970 & year <= 1999
* Standardize country names if needed
replace country = "South Korea" if country == "Republic of Korea"
replace country = "Vietnam" if country == "Viet Nam"
replace country = "Ivory Coast" if country == "Côte d'Ivoire"
replace country = "Czech Republic" if country == "Czechoslovakia"
replace country = "Congo, Dem. Rep." if country == "Democratic Republic of the Congo"
replace country = "Congo, Rep." if country == "Republic of the Congo"
replace country = "Russia" if country == "Russian Federation"
replace country = "Syria" if country == "Syrian Arab Republic"
replace country = "Iran" if country == "Iran (Islamic Republic of)"
replace country = "Bolivia" if country == "Bolivia (Plurinational State of)"
replace country = "Venezuala" if country == "Venezuela (Bolivarian Republic of)"
replace country = "Tanzania" if country == "U.R. of Tanzania: Mainland"
replace country = "Macedonia" if country == "North Macedonia"
replace country = "Laos" if country == "Lao People's DR"
keep country year rgdpe pop hc csh_i csh_x csh_m labsh
* Drop observations with missing key vars if necessary
drop if missing(country, year, rgdpe, pop)
* Save cleaned PWT data
save pwt_clean.dta, replace

**********************************
* 2. Load and Clean chat Data
**********************************
use chat.dta, clear
* Keep only 1970-1999
keep if year >= 1970 & year <= 1999

* Standardize country names similarly
replace country_name = "South Korea" if country_name == "South Korea"
replace country_name = "Ivory Coast" if country_name == "Côte d'Ivoire"
replace country_name = "Congo, Dem. Rep." if country_name == "Democratic Republic of the Congo"
replace country_name = "Congo, Rep." if country_name == "Republic of the Congo"
replace country_name = "Russia" if country_name == "Russian Federation"
replace country_name = "Syria" if country_name == "Syrian Arab Republic"
replace country_name = "Iran" if country_name == "Iran (Islamic Republic of)"
replace country_name = "Bosnia and Herzegovina" if country_name == "Bosnia-Herzegovina"
replace country_name = "Slovakia" if country_name == "Slovak Republic"
rename country_name country
* Keep selected tech variables
keep country year ag_tractor elecprod fert_total radio tv

* Drop observations missing country/year
drop if missing(country, year)

* Save cleaned chat data
save chat_clean.dta, replace

**********************************
* 3. Merge Datasets
**********************************
use pwt_clean.dta, clear
merge 1:1 country year using chat_clean.dta

* Drop unmatched observations
drop if _merge != 3
drop _merge

* Now we have rgdpe, pop, hc, csh_i, csh_x, csh_m, labsh plus tech vars

**********************************
* 4. Apply Data Restrictions
* For example, drop countries with fewer than 20 years of data
**********************************
bysort country: gen countyrs = _N
drop if countyrs < 20
drop countyrs

save merged_data.dta, replace

**********************************
* 5. Calculate Growth Rates
**********************************
use merged_data.dta, clear

* Reshape to wide format including all variables that vary by year
reshape wide rgdpe ag_tractor elecprod fert_total radio tv pop hc labsh csh_i csh_x csh_m, i(country) j(year)

* Calculate growth rates for GDP and technology variables only
foreach var in rgdpe ag_tractor elecprod fert_total radio tv {
    forvalues y = 1970(1)1998 {
        gen g_`var'`y' = 100 * ((`var'`y'+1 - `var'`y') / `var'`y') if !missing(`var'`y', `var'`y'+1)
    }
}

* Reshape back to long format
reshape long rgdpe ag_tractor elecprod fert_total radio tv pop hc labsh csh_i csh_x csh_m g_rgdpe g_ag_tractor g_elecprod g_fert_total g_radio g_tv, i(country) j(year)

* Drop 1999 since we can't calculate growth into 2000
drop if year == 1999

save growth_data.dta, replace


**********************************
* 6. Create Developed Dummy
**********************************
use growth_data.dta, clear
gen developed = 0
replace developed = 1 if inlist(country,"France","Germany","Italy","Japan","United Kingdom","United States")

save growth_data_with_dev.dta, replace

**********************************
* 7. Weighted Averages by Developed Status
**********************************
* We already have pop from the merged dataset. Just to confirm, we might need to re-merge population if needed.

* If we need population separately:
use growth_data_with_dev.dta, clear
* pop should be there from earlier steps since we kept it from PWT data

collapse (mean) g_rgdpe g_ag_tractor g_elecprod g_fert_total g_radio g_tv hc csh_i csh_x csh_m labsh [aw=pop], by(developed year)


graph twoway ///
    (line g_rgdpe year if developed==1, lcolor(blue) lwidth(medthick)) ///
    (line g_rgdpe year if developed==0, lcolor(red) lwidth(medthick)), ///
    title("Population-Weighted Average GDP Growth: Developed vs. Non-Developed") ///
    legend(order(1 "Developed" 2 "Non-Developed"))

save dev_nondev_summary.dta, replace

**********************************
* 8. Summary Statistics
**********************************
* For summary stats, go back to the detailed dataset with all countries
use growth_data_with_dev.dta, clear

gen trade_openness = csh_x + csh_m

tabstat g_rgdpe g_ag_tractor g_elecprod g_fert_total g_radio g_tv hc csh_i trade_openness labsh, ///
    statistics(mean sd min max) columns(statistics)

**********************************
* 9. Regression Analysis
**********************************
* Simple regression including controls
reg g_rgdpe g_ag_tractor g_elecprod g_fert_total g_radio g_tv hc csh_i trade_openness labsh

* Separate by developed status
reg g_rgdpe g_ag_tractor g_elecprod g_fert_total g_radio g_tv hc csh_i trade_openness labsh if developed == 1
reg g_rgdpe g_ag_tractor g_elecprod g_fert_total g_radio g_tv hc csh_i trade_openness labsh if developed == 0

save final_results.dta, replace

*****************************************************
* End of Do-File
*****************************************************
