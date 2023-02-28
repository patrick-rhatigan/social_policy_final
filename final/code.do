clear all
cap program drop _all

global folder "~/OneDrive/School_Work/junior_spring/social_policy/final"

use "$folder/data/YRBS_AK_ME_NV.dta"
set scheme plottig

*drop if marijuana questions are unasnwered
drop if q45 == . & q47 == .

*generate dummy for ever used marijuana (any >1 for q45)
gen ever_marij = 0 if q45 == 1
replace ever_marij = 1 if q45 >1 & q45<.

*generate dummy for marijuana use this month
gen marij_30 = 0 if q47 == 1
replace marij_30 = 1 if q47 >1 & q47<.

*change so males are 0, females are 1
replace sex = 0 if sex ==2
replace sex = 1 if sex ==1
lab var sex "Female"

*alter grade variable:
replace grade = 9 if grade ==1
replace grade = 10 if grade ==2
replace grade = 11 if grade ==3
replace grade = 12 if grade ==4

*generate grade and race indicators
tab grade, gen(g_)

gen r_w = 0 
gen r_ami = 0
gen r_as = 0
gen r_b = 0
gen r_h = 0
gen r_o = 0
replace r_w = 1 if race7 == 6
replace r_ami = 1 if race7 == 1
replace r_as = 1 if race7 == 2
replace r_b = 1 if race7 == 3
replace r_h = 1 if race7 == 4
replace r_o = 1 if race7 == 5 | race7 == 7
lab var r_ami "American Indian/Alaska Native"
lab var r_as "Asian"
lab var r_b "Black/African American"
lab var r_h "Hispanic/Latino" 
lab var r_w "White"
lab var r_o "Other Race"


lab var g_1 "9th Grade"
lab var g_2 "10th Grade"
lab var g_3 "11th Grade" 
lab var g_4 "12th Grade"

*gen sitecode dummy:
gen sitenum = 1
replace sitenum = 2 if sitecode=="ME"
replace sitenum = 3 if sitecode == "NV"

lab var ever_marij "Ever Used Marijuana"
lab var marij_30 "Used Marijuana in the Past 30 Days"
lab var sitecode "State"


*Summary statistics tables:
eststo a1: estpost summ  g_* r_* sex if sitecode == "AK"

eststo a2: estpost summ  g_* r_* sex if sitecode == "ME"

eststo a3: estpost summ  g_* r_* sex if sitecode == "NV"

esttab a*, main(mean %6.2f) aux(sd %6.2f) mtitle("Alaska" "Maine" "Nevada")

esttab a* using "$folder/tabs/a.tex", replace ///
  main(mean %15.2fc) aux(sd %15.2fc) nostar nonumber unstack ///
   compress gap label booktabs f ///
   collabels(none) mtitle("Alaska" "Maine" "Nevada")

*generate year_event = year of recreational legilization
gen year_event = 2016
replace year_event = 2014 if sitecode == "AK"

gen event_time = 0 if year == year_event

*generate lags
forvalues  j = 1(1)7 {
			replace event_time = -`j' if year == (year_event)-`j'		
			}


*generating leads
forvalues j = 1(1)5 {
			replace event_time = `j' if year == (year_event) +`j'		
			}

lab var event_time "Year Relative to Legilization"
	
	
preserve 
collapse (mean) ever_marij marij_30 sex g_* r_* ///
	(sd) sd_ever_marij = ever_marij sd_marij_30 = marij_30 ///
	     sd_sex = sex sd_grade = grade ///
	(count) n = sitenum , by(event_time sitecode)

gen ci_ever_up = ever_marij + 1.96*sd_ever_marij/sqrt(n) 
gen ci_ever_down = ever_marij - 1.96*sd_ever_marij/sqrt(n)

gen ci_30_up = marij_30 + 1.96*sd_marij_30/sqrt(n) 
gen ci_30_down = marij_30 - 1.96*sd_marij_30/sqrt(n)

gen ci_sex_up = sex + 1.96*sd_sex/sqrt(n) 
gen ci_sex_down = sex - 1.96*sd_sex/sqrt(n)

eststo b1: estpost summ  g_* r_* sex if sitecode == "AK"

eststo b2: estpost summ  g_* r_* sex if sitecode == "ME"

eststo b3: estpost summ  g_* r_* sex if sitecode == "NV"

esttab b*  using "$folder/tabs/z.tex", replace ///
	cells("min(fmt(%15.2fc))" "max(fmt(%15.2fc))") ///
	mtitle("Alaska" "Maine" "Nevada") nostar unstack nonumber ///
	compress nonote noobs gap label booktabs f  ///
	collabels(none)


graph box g_*, by(sitecode, cols(1)) ysize(8) ytitle("Grade Share") ///
	legend(order (1 "9th Grade" 2 "10th Grade" 3 "11th Grade" 4 "12th Grade"))
graph export "$folder/figs/grades.png", replace	

graph box r_*, by(sitecode, cols(1)) ysize(8) ytitle("Racial Share") 
	*legend(order (1 "9th Grade" 2 "10th Grade" 3 "11th Grade" 4 "12th Grade"))
graph export "$folder/figs/races.png", replace	


scatter ever_marij event_time || rcap ci_ever_up ci_ever_down event_time, ///
	xline(0) by(sitecode, cols(1)) ytitle("Ever Used Marijuana") ///
	legend(order(2 "95% Confidence Intervals")) ysize(8) 
graph export "$folder/figs/ever_marij.png", replace		
	
scatter marij_30 event_time || rcap ci_30_up ci_30_down event_time, ///
	xline(0) by(sitecode, cols(1)) ytitle("Used Marijuana in the Last 30 Days") ///
	legend(order(2 "95% Confidence Intervals")) ysize(8)
graph export "$folder/figs/marij_30.png", replace	

scatter sex event_time || rcap ci_sex_up ci_sex_down event_time, ///
	xline(0) by(sitecode, cols(1)) ytitle("Share Female") ///
	legend(order(2 "95% Confidence Intervals")) ysize(8)
graph export "$folder/figs/sex.png", replace		


restore

replace event_time = event_time + 7	
*this is done because regressions when values are negative are difficult for stata

*my basic event time regression of ever using marijuana without controls	
eststo ever_nocontrol: ///
	areg ever_marij ib6.event_time, absorb(sitecode) r
	  estadd local  Sex  "No"
	  estadd local  Grade  "No"
	  estadd local  Race  "No"
	  
*the coefficient plot of the above regression
coefplot, keep(*.event_time) vertical yline(0) xline(4.5) base ///
	rename(0.event_time="-7" 2.event_time="-5" 4.event_time="-3" 6.event_time="-1" ///
	8.event_time="1" 10.event_time="3" 12.event_time ="5") ///
	ciopts(recast(rcap) lcolor("midblue")) xtitle("Year Relative to Legalization") ///
	ytitle("Coefficient") 
graph export "$folder/figs/ever_coefplot.png", replace	

*ever using marijuana with grade controls	
eststo ever_g: ///
	areg ever_marij ib6.event_time sex g_1 g_2 g_3, absorb(sitecode) r
	  estadd local  Sex  "Yes"
	  estadd local  Grade  "Yes"
	  estadd local  Race  "No"
*ever using marijuana with sex & race controls	
eststo ever_r: ///
	areg ever_marij ib6.event_time sex r_ami r_as r_b r_h r_o, absorb(sitecode) r
	  estadd local  Sex  "Yes"
	  estadd local  Grade  "No"
	  estadd local  Race  "Yes"
*ever using marijuana with grade, sex & race controls	
eststo ever_gr: ///
	areg ever_marij ib6.event_time sex g_1 g_2 g_3 r_ami r_as r_b r_h r_o, absorb(sitecode) r
	  estadd local  Sex  "Yes"
	  estadd local  Grade  "Yes"
	  estadd local  Race  "Yes"


*my basic event time regression of marijuana use in the past 30 days 
* without controls	
eststo m30_nocontrol: ///
	areg marij_30 ib6.event_time, absorb(sitecode) r
	  estadd local  Sex  "No"
	  estadd local  Grade  "No"
	  estadd local  Race  "No"
	  
*the coefficient plot of the above regression	  
coefplot, keep(*.event_time) vertical yline(0) xline(4.5) base ///
	rename(0.event_time="-7" 2.event_time="-5" 4.event_time="-3" 6.event_time="-1" ///
	8.event_time="1" 10.event_time="3" 12.event_time ="5") ///
	ciopts(recast(rcap) lcolor("midblue")) xtitle("Year Relative to Legalization") ///
	ytitle("Coefficient")
graph export "$folder/figs/30_coefplot.png", replace

*used marijuana in past 30 days with grade controls	
eststo m30_g: ///
	areg marij_30 ib6.event_time sex g_1 g_2 g_3, absorb(sitecode) r
	  estadd local  Sex  "Yes"
	  estadd local  Grade  "Yes"
	  estadd local  Race  "No"
*used marijuana in past 30 days with race & sex controls	
eststo m30_r: ///
	areg marij_30 ib6.event_time sex r_ami r_as r_b r_h r_o, absorb(sitecode) r
	  estadd local  Sex  "Yes"
	  estadd local  Grade  "No"
	  estadd local  Race  "Yes"
*used marijuana in past 30 days with grade, race & sex controls
eststo m30_gr: ///
	areg marij_30 ib6.event_time sex g_1 g_2 g_3 r_ami r_as r_b r_h r_o, absorb(sitecode) r
	  estadd local  Sex  "Yes"
	  estadd local  Grade  "Yes"
	  estadd local  Race  "Yes"


*creating a table of the above regressions
esttab ever_nocontrol ever_g ever_r ever_gr m30_* using "$folder/tabs/b.tex", replace f ///
	b(3) se(3) ///
	keep(0.event_time 2.event_time 4.event_time 8.event_time 10.event_time 12.event_time) ///
	coeflabel(0.event_time "-7" 2.event_time "-5" 4.event_time "-3" 6.event_time "-1" ///
	8.event_time "1" 10.event_time "3" 12.event_time "5") ///
	label booktabs nomtitle noobs collabels(none) compress nostar alignment(D{.}{.}{-1}) ///
	scalars("Sex Sex Controls" "Race Race Controls" "Grade Grade Controls") sfmt(3) ///
	mgroups("Ever Used " "Used in Past 30 Days", pattern(1 0 0 0 1 0 0 0) ///
	prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span}))

/*the below regressions looked at specific sub-populations to see if marijuana 
  was more or less prevalent among white students or female students */
eststo white_1: ///
	areg ever_marij ib6.event_time sex, absorb(sitecode) r
	  estadd local  Race  "No"
eststo white_2: ///
	areg ever_marij ib6.event_time sex r_w, absorb(sitecode) r
	  estadd local  Race  "No"
eststo white_4: ///
	areg marij_30 ib6.event_time sex, absorb(sitecode) r
	  estadd local  Race  "No"
eststo white_5: ///
	areg marij_30 ib6.event_time sex r_w, absorb(sitecode) r
	  estadd local  Race  "No"

*tabulating the regression results
esttab white_* using "$folder/tabs/c.tex", replace f ///
	b(3) se(3) ///
	keep(r_w sex) ///
	coeflabel(r_w "White" sex "Female") ///
	label booktabs nomtitle noobs collabels(none) compress nostar alignment(D{.}{.}{-1}) ///
	mgroups("Ever Used " "Used in Past 30 Days", pattern(1 0 1 0) ///
	prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span}))
	

/* The following section creates coefficient plots for the subpopulation 
   regressions from above */
preserve
keep if sex == 0
eststo exp_1: ///
	areg marij_30 ib6.event_time, absorb(sitecode) r
	
coefplot, keep(*.event_time) vertical yline(0) xline(4.5) base ///
	rename(0.event_time="-7" 2.event_time="-5" 4.event_time="-3" 6.event_time="-1" ///
	8.event_time="1" 10.event_time="3" 12.event_time ="5") ///
	ciopts(recast(rcap) lcolor("midblue")) xtitle("Year Relative to Legalization") ///
	ytitle("Coefficient") 
graph export "$folder/figs/male_cp.png", replace
restore


preserve
keep if sex == 1
eststo exp_1: ///
	areg marij_30 ib6.event_time, absorb(sitecode) r
	
coefplot, keep(*.event_time) vertical yline(0) xline(4.5) base ///
	rename(0.event_time="-7" 2.event_time="-5" 4.event_time="-3" 6.event_time="-1" ///
	8.event_time="1" 10.event_time="3" 12.event_time ="5") ///
	ciopts(recast(rcap) lcolor("midblue")) xtitle("Year Relative to Legalization") ///
	ytitle("Coefficient") 
graph export "$folder/figs/female_cp.png", replace
restore


preserve
keep if r_w == 1
eststo exp_2: ///
	areg marij_30 ib6.event_time, absorb(sitecode) r
coefplot, keep(*.event_time) vertical yline(0) xline(4.5) base ///
	rename(0.event_time="-7" 2.event_time="-5" 4.event_time="-3" 6.event_time="-1" ///
	8.event_time="1" 10.event_time="3" 12.event_time ="5") ///
	ciopts(recast(rcap) lcolor("midblue")) xtitle("Year Relative to Legalization") ///
	ytitle("Coefficient") 
graph export "$folder/figs/white_cp.png", replace
restore

preserve
keep if r_w == 0
eststo exp_2: ///
	areg marij_30 ib6.event_time, absorb(sitecode) r
coefplot, keep(*.event_time) vertical yline(0) xline(4.5) base ///
	rename(0.event_time="-7" 2.event_time="-5" 4.event_time="-3" 6.event_time="-1" ///
	8.event_time="1" 10.event_time="3" 12.event_time ="5") ///
	ciopts(recast(rcap) lcolor("midblue")) xtitle("Year Relative to Legalization") ///
	ytitle("Coefficient")
graph export "$folder/figs/non_white_cp.png", replace
restore

