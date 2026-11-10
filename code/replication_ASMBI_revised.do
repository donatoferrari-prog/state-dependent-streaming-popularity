/**************************************************************************
  REPLICATION FILE
  State-Dependent Modelling of Streaming Popularity:
  Feature-Specific Heterogeneity in Digital Music Consumption

  Revised version - ASMBI Practitioner's Corner

  IMPORTANT:
  - The original dataset is NEVER overwritten.
  - All derived variables are reconstructed from the original data.
**************************************************************************/

version 18
clear all
set more off

*==========================================================================
* 00. PATHS
*==========================================================================

* Repository paths
global ROOT "."
global DATA "$ROOT/data"
global OUTPUT "$ROOT/output"

* Original input data
global RAW "$DATA/charts analysis_working.dta"

capture mkdir "$OUTPUT"


*==========================================================================
* 01. LOAD ORIGINAL DATA
*==========================================================================

use "$RAW", clear

display "============================================================"
display "CHECK 01 - ORIGINAL DATASET"
display "Expected observations: 118321"
display "============================================================"

count

assert _N == 118321


*==========================================================================
* 02. BASIC DATA CHECKS
*==========================================================================

describe track_id week streams position ///
    af_danceability af_loudness ///
    es_dynamic_complexity es_onset_rate ///
    af_source

* Dependent variable must be strictly positive before taking logs
count if streams <= 0 | missing(streams)

* Date coverage
summ week

* Chart-position coverage
summ position, detail

* Number of unique tracks in full dataset
capture drop tag_track_full
egen tag_track_full = tag(track_id)

count if tag_track_full == 1

display "Expected number of unique tracks in full working dataset: 8956"


*==========================================================================
* 03. PANEL IDENTIFIER AND DEPENDENT VARIABLE
*==========================================================================

capture drop track_num
egen track_num = group(track_id)

capture drop log_streams_check
gen double log_streams_check = ln(streams)

label variable log_streams_check "Natural log of weekly streams"

* Verify transformation
summ streams log_streams_check


*==========================================================================
* 04. CONSTRUCTION OF WEEKLY FEATURE DEVIATIONS
*
* Novelty is defined as the SIGNED deviation of each track's feature
* from the contemporaneous weekly chart mean.
*
* nov_it = x_i - mean(x_t)

*
* Interpretation:
* nov_it combines a track-specific audio characteristic with the
* contemporaneous composition of the weekly chart. A positive value
* indicates that track i has a higher feature value than the average
* track appearing in the chart in week t; a negative value indicates
* the opposite.
*
* Consequently, the interaction nov_it × c_lag does not represent
* a purely time-invariant track characteristic. It measures whether
* the association between a track's relative audio position within
* the contemporaneous weekly chart and current streaming popularity
* varies with that track's prior-week popularity state.

*==========================================================================

*-----------------------------
* Danceability
*-----------------------------

capture drop mean_dance nov_dance
bysort week: egen double mean_dance = mean(af_danceability)
gen double nov_dance = af_danceability - mean_dance

label variable nov_dance ///
    "Danceability deviation from contemporaneous weekly mean"


*-----------------------------
* Loudness
*-----------------------------

capture drop mean_loud nov_loud
bysort week: egen double mean_loud = mean(af_loudness)
gen double nov_loud = af_loudness - mean_loud

label variable nov_loud ///
    "Loudness deviation from contemporaneous weekly mean"


*-----------------------------
* Dynamic complexity
*-----------------------------

capture drop mean_complex nov_complex
bysort week: egen double mean_complex = mean(es_dynamic_complexity)
gen double nov_complex = es_dynamic_complexity - mean_complex

label variable nov_complex ///
    "Dynamic-complexity deviation from contemporaneous weekly mean"


*-----------------------------
* Onset rate
*-----------------------------

capture drop mean_onset nov_onset
bysort week: egen double mean_onset = mean(es_onset_rate)
gen double nov_onset = es_onset_rate - mean_onset

label variable nov_onset ///
    "Onset-rate deviation from contemporaneous weekly mean"


* Check construction
summ nov_dance nov_loud nov_complex nov_onset

* Weekly deviations should average approximately zero within each week
bysort week: egen double check_mean_dance = mean(nov_dance)
bysort week: egen double check_mean_loud = mean(nov_loud)
bysort week: egen double check_mean_complex = mean(nov_complex)
bysort week: egen double check_mean_onset = mean(nov_onset)

summ check_mean_dance check_mean_loud ///
     check_mean_complex check_mean_onset

drop check_mean_dance check_mean_loud ///
     check_mean_complex check_mean_onset


*==========================================================================
* 05. CONSTRUCTION OF LAGGED POPULARITY
*
* Two definitions are generated:
*
* (1) lag_prevobs:
*     previous OBSERVED chart appearance of the same track.
*
* (2) lag_weekly:
*     previous observation only when exactly 7 days earlier.
*
* The revised baseline uses lag_weekly.
*==========================================================================

sort track_num week

capture drop lag_prevobs gap_days lag_weekly

bysort track_num (week): ///
    gen double lag_prevobs = log_streams_check[_n-1]

bysort track_num (week): ///
    gen gap_days = week - week[_n-1]

gen double lag_weekly = lag_prevobs if gap_days == 7

label variable lag_prevobs ///
    "Log streams at previous observed chart appearance"

label variable lag_weekly ///
    "Log streams exactly one week earlier"

label variable gap_days ///
    "Days since previous observed chart appearance"


*==========================================================================
* 06. VERIFY LAG CONSTRUCTION AND ESTIMATION SAMPLES
*==========================================================================

display "============================================================"
display "CHECK 02 - LAG CONSTRUCTION"
display "============================================================"

count if !missing(lag_prevobs)
display "Expected: 109365"

count if !missing(lag_weekly)
display "Expected: 105007"


* Complete-feature samples
capture drop sample_prevobs sample_weekly

gen byte sample_prevobs = ///
    !missing(lag_prevobs) & ///
    !missing(nov_dance, nov_loud, nov_complex, nov_onset)

gen byte sample_weekly = ///
    !missing(lag_weekly) & ///
    !missing(nov_dance, nov_loud, nov_complex, nov_onset)


count if sample_prevobs == 1
display "Expected previous-observation sample: 109344"

count if sample_weekly == 1
display "Expected revised weekly sample: 104986"

assert r(N) == 104986


* Exit/re-entry diagnostic
count if sample_prevobs == 1 & gap_days > 7

display "Expected non-consecutive previous observations: 4358"


*==========================================================================
* 07. CONSTRUCT REVISED ESTIMATION SAMPLE
*==========================================================================

* Mean lag calculated strictly within revised estimation sample
summ lag_weekly if sample_weekly == 1, meanonly

scalar mean_lag_weekly = r(mean)

display "Mean log prior-week streams = " mean_lag_weekly


capture drop c_lag
gen double c_lag = lag_weekly - mean_lag_weekly ///
    if sample_weekly == 1

label variable c_lag ///
    "Centered log prior-week streams"


* Week fixed-effect identifier
capture drop week_fe
egen week_fe = group(week)

label variable week_fe "Week fixed-effect identifier"


* Verify centering
summ c_lag if sample_weekly == 1, detail


* Number of tracks in revised sample
capture drop tag_track_revised
egen tag_track_revised = tag(track_num) if sample_weekly == 1

count if tag_track_revised == 1

display "Expected tracks in revised sample: 6231"

assert r(N) == 6231


* Final core sample verification
count if sample_weekly == 1

assert r(N) == 104986


display "============================================================"
display "CORE REPLICATION SAMPLE SUCCESSFULLY RECONSTRUCTED"
display "OBSERVATIONS = 104986"
display "TRACKS       = 6231"
display "============================================================"

*==========================================================================
* 08. DESCRIPTIVE STATISTICS AND FEATURE PROVENANCE
*     Revised estimation sample
*==========================================================================

display "============================================================"
display "SECTION 08 - DESCRIPTIVES AND PROVENANCE"
display "============================================================"

*------------------------------------------------------------
* 08.1 Core descriptive statistics
*------------------------------------------------------------

summ log_streams_check c_lag ///
     nov_dance nov_loud nov_complex nov_onset ///
     if sample_weekly == 1

* More detailed distribution of centered lag
summ c_lag if sample_weekly == 1, detail

*------------------------------------------------------------
* 08.2 Distribution of observations per track
*------------------------------------------------------------

capture drop n_obs_track_revised tag_track_obs

bysort track_num: egen n_obs_track_revised = ///
    total(sample_weekly == 1)

egen tag_track_obs = tag(track_num) if sample_weekly == 1

summ n_obs_track_revised if tag_track_obs == 1, detail

*------------------------------------------------------------
* Track-history length diagnostics
* Reviewer request: document the prevalence of short histories
*------------------------------------------------------------

count if tag_track_obs == 1 & n_obs_track_revised == 1
display "Expected tracks with 1 usable observation: 1022"

count if tag_track_obs == 1 & n_obs_track_revised == 2
display "Expected tracks with 2 usable observations: 605"

count if tag_track_obs == 1 & n_obs_track_revised == 3
display "Expected tracks with 3 usable observations: 442"

count if tag_track_obs == 1 & n_obs_track_revised < 4
display "Expected tracks with fewer than 4 usable observations: 2069"

count if tag_track_obs == 1 & n_obs_track_revised < 8
display "Expected tracks with fewer than 8 usable observations: 3063"

count if tag_track_obs == 1 & n_obs_track_revised >= 8
display "Expected tracks with at least 8 usable observations: 3168"

*------------------------------------------------------------
* 08.3 Sample-selection diagnostics
*      Reviewer request: assess selection induced by the
*      exact-week lag requirement and external validity
*------------------------------------------------------------

preserve

* Full number of chart appearances for each track
bysort track_num: gen n_obs_full = _N

* Indicator: track contributes at least one observation
* to the main exact-week-lag estimation sample
bysort track_num: egen byte enters_main = max(sample_weekly)

* Track-level descriptive characteristics
bysort track_num: egen double mean_streams_track = mean(streams)
bysort track_num: egen double max_streams_track  = max(streams)
bysort track_num: egen double best_position_track = min(position)

* Keep one observation per track
egen byte tag_track_selection = tag(track_num)
keep if tag_track_selection == 1

display "============================================================"
display "SAMPLE-SELECTION DIAGNOSTICS"
display "============================================================"

count
display "Expected total tracks: 8956"

count if enters_main == 1
display "Expected tracks entering main sample: 6231"

count if enters_main == 0
display "Expected excluded tracks: 2725"

* Most exclusions should be mechanically due to one appearance only
count if enters_main == 0 & n_obs_full == 1
display "Expected excluded one-appearance tracks: 2578"

count if enters_main == 0 & n_obs_full >= 2
display "Expected excluded tracks with >=2 appearances: 147"

* Among tracks appearing at least twice
count if n_obs_full >= 2
display "Expected tracks with >=2 appearances: 6378"

count if enters_main == 1 & n_obs_full >= 2
display "Expected included among tracks with >=2 appearances: 6231"

* Compare included and excluded tracks
tabstat n_obs_full mean_streams_track max_streams_track ///
    best_position_track, ///
    by(enters_main) ///
    statistics(n mean p50 min max) ///
    columns(statistics)

*------------------------------------------------------------
* Export track-level sample-selection diagnostics
*------------------------------------------------------------

export delimited using ///
    "output/sample_selection_track_level.csv", ///
    replace

export excel using ///
    "output/final_tables.xlsx", ///
    sheet("Sample selection") ///
    firstrow(variables) ///
    sheetreplace

restore

*------------------------------------------------------------
* 08.4 Feature-source provenance at TRACK level
*------------------------------------------------------------

capture drop tag_track_source

egen tag_track_source = tag(track_num) ///
    if sample_weekly == 1

display "Feature-source provenance - revised estimation sample"

tab af_source if tag_track_source == 1, missing

* Number of unique tracks in revised sample
count if tag_track_source == 1

*------------------------------------------------------------
* 08.5 Compact provenance table
*------------------------------------------------------------

preserve

keep if sample_weekly == 1
keep if tag_track_source == 1

contract af_source, freq(n_tracks)

egen total_tracks_source = total(n_tracks) ///
    if !missing(af_source)

gen pct_tracks = ///
    100 * n_tracks / total_tracks_source ///
    if !missing(af_source)

format pct_tracks %9.2f

list af_source n_tracks pct_tracks, ///
    noobs clean

restore

*------------------------------------------------------------
* 08.6 Source-specific distributions
*     Used to document comparability across providers
*------------------------------------------------------------

tabstat af_danceability af_loudness ///
    if sample_weekly == 1, ///
    by(af_source) ///
    statistics(n mean sd p25 p50 p75 min max) ///
    columns(statistics)

*------------------------------------------------------------
* 08.7 Simple feature correlations
*------------------------------------------------------------

pwcorr nov_dance nov_loud nov_complex nov_onset ///
    if sample_weekly == 1, sig obs


*==========================================================================
* 09. REVISED BASELINE - JOINT MODEL
*
* True weekly lag
* Week fixed effects
* Standard errors clustered by track
*==========================================================================

display "============================================================"
display "SECTION 09 - REVISED BASELINE JOINT MODEL"
display "============================================================"

reg log_streams_check ///
    c_lag ///
    nov_dance nov_loud nov_complex nov_onset ///
    c.nov_dance#c.c_lag ///
    c.nov_loud#c.c_lag ///
    c.nov_complex#c.c_lag ///
    c.nov_onset#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    vce(cluster track_num)

estimates store revised_joint

*------------------------------------------------------------
* 09.1 Persistence-only benchmark
*     Reviewer request: compare the full model with a model
*     containing only prior-week popularity and week FE
*------------------------------------------------------------

reg log_streams_check ///
    c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    vce(cluster track_num)

estimates store persistence_benchmark

display "============================================================"
display "PERSISTENCE-ONLY BENCHMARK"
display "Expected R2      ≈ 0.97118476"
display "Expected Adj R2  ≈ 0.97099912"
display "Expected RMSE    ≈ 0.18103223"
display "============================================================"

display "Benchmark R2     = " e(r2)
display "Benchmark Adj R2 = " e(r2_a)
display "Benchmark RMSE   = " e(rmse)

scalar r2_benchmark   = e(r2)
scalar rmse_benchmark = e(rmse)


* Restore full model and compare fit
estimates restore revised_joint

display "Full-model R2     = " e(r2)
display "Full-model Adj R2 = " e(r2_a)
display "Full-model RMSE   = " e(rmse)

scalar r2_full   = e(r2)
scalar rmse_full = e(rmse)


* Incremental fit of the audio-feature terms
scalar delta_r2 = r2_full - r2_benchmark

scalar rmse_reduction_pct = ///
    100 * (rmse_benchmark - rmse_full) / rmse_benchmark

display "============================================================"
display "INCREMENTAL FIT OF AUDIO FEATURES"
display "Delta R2              = " delta_r2
display "Expected Delta R2     ≈ 0.00012"
display "RMSE reduction (%)    = " rmse_reduction_pct
display "Expected reduction    ≈ 0.2046%"
display "============================================================"

* Joint test of the eight added audio-feature terms
test ///
    nov_dance nov_loud nov_complex nov_onset ///
    c.nov_dance#c.c_lag ///
    c.nov_loud#c.c_lag ///
    c.nov_complex#c.c_lag ///
    c.nov_onset#c.c_lag

display "Expected joint test: F(8,6230) ≈ 14.34, p < 0.001"

*------------------------------------------------------------
* 09.2 Replication checks
*------------------------------------------------------------

display "Expected N = 104986"
display "Expected clusters = 6231"

display "Expected c_lag coefficient ≈ 0.9422393"
display "Expected dance x lag ≈ 0.0072112"
display "Expected loud x lag ≈ 0.0011813"
display "Expected complex x lag ≈ -0.0016833"
display "Expected onset x lag ≈ -0.0089055"

* Point-estimate checks with small numerical tolerance

assert abs(_b[c_lag] - 0.9422393) < 0.00001

assert abs(_b[c.nov_dance#c.c_lag] - 0.0072112) < 0.00001

assert abs(_b[c.nov_loud#c.c_lag] - 0.0011813) < 0.00001

assert abs(_b[c.nov_complex#c.c_lag] + 0.0016833) < 0.00001

assert abs(_b[c.nov_onset#c.c_lag] + 0.0089055) < 0.00001

display "============================================================"
display "REVISED BASELINE SUCCESSFULLY REPLICATED"
display "============================================================"

*==========================================================================
* 10. FEATURE-SPECIFIC MODELS
*==========================================================================

display "============================================================"
display "SECTION 10 - FEATURE-SPECIFIC MODELS"
display "============================================================"

*------------------------------------------------------------
* 10.1 Danceability
*------------------------------------------------------------

reg log_streams_check ///
    c_lag ///
    nov_dance ///
    c.nov_dance#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    vce(cluster track_num)

estimates store fs_dance


*------------------------------------------------------------
* 10.2 Loudness
*------------------------------------------------------------

reg log_streams_check ///
    c_lag ///
    nov_loud ///
    c.nov_loud#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    vce(cluster track_num)

estimates store fs_loud


*------------------------------------------------------------
* 10.3 Dynamic complexity
*------------------------------------------------------------

reg log_streams_check ///
    c_lag ///
    nov_complex ///
    c.nov_complex#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    vce(cluster track_num)

estimates store fs_complex


*------------------------------------------------------------
* 10.4 Onset rate
*------------------------------------------------------------

reg log_streams_check ///
    c_lag ///
    nov_onset ///
    c.nov_onset#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    vce(cluster track_num)

estimates store fs_onset


*------------------------------------------------------------
* 10.5 Expected interaction estimates
*------------------------------------------------------------

display "Feature-specific interaction checks"

estimates restore fs_dance
display "Dance x lag expected ≈ -0.0099697"
assert abs(_b[c.nov_dance#c.c_lag] + 0.0099697) < 0.00001

estimates restore fs_loud
display "Loud x lag expected ≈ 0.0011625"
assert abs(_b[c.nov_loud#c.c_lag] - 0.0011625) < 0.00001

estimates restore fs_complex
display "Complex x lag expected ≈ -0.0027225"
assert abs(_b[c.nov_complex#c.c_lag] + 0.0027225) < 0.00001

estimates restore fs_onset
display "Onset x lag expected ≈ -0.0083991"
assert abs(_b[c.nov_onset#c.c_lag] + 0.0083991) < 0.00001

display "FEATURE-SPECIFIC MODELS SUCCESSFULLY REPLICATED"


*==========================================================================
* 11. MARGINAL EFFECTS AND ZERO-CROSSINGS
*==========================================================================

display "============================================================"
display "SECTION 11 - MARGINAL EFFECTS AND ZERO-CROSSINGS"
display "============================================================"

* Restore revised joint model
estimates restore revised_joint


*------------------------------------------------------------
* 11.1 Distribution of centered lag
*------------------------------------------------------------

summ c_lag if sample_weekly == 1, detail

local p10 = r(p10)
local p25 = r(p25)
local p50 = r(p50)
local p75 = r(p75)
local p90 = r(p90)

display "P10 = " `p10'
display "P25 = " `p25'
display "P50 = " `p50'
display "P75 = " `p75'
display "P90 = " `p90'


*------------------------------------------------------------
* 11.2 Marginal effects at representative popularity levels
*------------------------------------------------------------

estimates restore revised_joint

margins, dydx(nov_dance) ///
    at(c_lag=(`p10' `p25' `p50' `p75' `p90'))

estimates restore revised_joint

margins, dydx(nov_loud) ///
    at(c_lag=(`p10' `p25' `p50' `p75' `p90'))

estimates restore revised_joint

margins, dydx(nov_complex) ///
    at(c_lag=(`p10' `p25' `p50' `p75' `p90'))

estimates restore revised_joint

margins, dydx(nov_onset) ///
    at(c_lag=(`p10' `p25' `p50' `p75' `p90'))

*------------------------------------------------------------
* 11.3 Practical magnitude: one-SD percentage differences
*      Reviewer request: translate effects into realistic
*      percentage differences in weekly streams
*------------------------------------------------------------

estimates restore revised_joint

* Standard deviations of novelty measures in the main sample
quietly summarize nov_loud if sample_weekly == 1
scalar sd_loud = r(sd)

quietly summarize nov_onset if sample_weekly == 1
scalar sd_onset = r(sd)

display "Expected SD loudness novelty ≈ 2.760377"
display "Expected SD onset-rate novelty ≈ 0.7994258"


* Retrieve coefficients from preferred joint specification
scalar b_loud = _b[nov_loud]
scalar g_loud = _b[c.nov_loud#c.c_lag]

scalar b_onset = _b[nov_onset]
scalar g_onset = _b[c.nov_onset#c.c_lag]


*------------------------------------------------------------
* Loudness: percentage difference for +1 SD
*------------------------------------------------------------

scalar loud_pct_p25 = ///
    100 * (exp(sd_loud * (b_loud + g_loud*`p25')) - 1)

scalar loud_pct_p50 = ///
    100 * (exp(sd_loud * (b_loud + g_loud*`p50')) - 1)

scalar loud_pct_p75 = ///
    100 * (exp(sd_loud * (b_loud + g_loud*`p75')) - 1)

display "============================================================"
display "LOUDNESS: +1 SD PERCENTAGE DIFFERENCE IN WEEKLY STREAMS"
display "P25 = " loud_pct_p25 "   Expected ≈ 0.212%"
display "P50 = " loud_pct_p50 "   Expected ≈ 0.427%"
display "P75 = " loud_pct_p75 "   Expected ≈ 0.575%"
display "============================================================"


*------------------------------------------------------------
* Onset rate: percentage difference for +1 SD
*------------------------------------------------------------

scalar onset_pct_p25 = ///
    100 * (exp(sd_onset * (b_onset + g_onset*`p25')) - 1)

scalar onset_pct_p50 = ///
    100 * (exp(sd_onset * (b_onset + g_onset*`p50')) - 1)

scalar onset_pct_p75 = ///
    100 * (exp(sd_onset * (b_onset + g_onset*`p75')) - 1)

display "============================================================"
display "ONSET RATE: +1 SD PERCENTAGE DIFFERENCE IN WEEKLY STREAMS"
display "P25 = " onset_pct_p25 "   Expected ≈ -0.422%"
display "P50 = " onset_pct_p50 "   Expected ≈ -0.886%"
display "P75 = " onset_pct_p75 "   Expected ≈ -1.205%"
display "============================================================"

*------------------------------------------------------------
* 11.4 Zero-crossings
*------------------------------------------------------------

estimates restore revised_joint

* Zero-crossings are reported only for features with
* precisely estimated interaction terms.
* Danceability and dynamic complexity are omitted because
* coefficient-ratio inference is unreliable when the
* interaction coefficient in the denominator is imprecise.

nlcom (loud_zero: ///
    -_b[nov_loud] / _b[c.nov_loud#c.c_lag])

display "Expected loudness zero-crossing ≈ -1.110"
display "Expected delta-method 95% CI ≈ [-1.888, -0.332]"

nlcom (onset_zero: ///
    -_b[nov_onset] / _b[c.nov_onset#c.c_lag])

display "Expected onset-rate zero-crossing ≈ -1.054"
display "Expected delta-method 95% CI ≈ [-1.392, -0.717]"


*------------------------------------------------------------
* 11.5 Empirical support around relevant zero-crossings
*------------------------------------------------------------

count if c_lag < -1.110257 & sample_weekly == 1
display "Expected observations below loudness zero-crossing: 18059"

count if c_lag >= -1.110257 & sample_weekly == 1
display "Expected observations above loudness zero-crossing: 86927"

count if c_lag < -1.054223 & sample_weekly == 1
display "Expected observations below onset zero-crossing: 18834"

count if c_lag >= -1.054223 & sample_weekly == 1
display "Expected observations above onset zero-crossing: 86152"


*------------------------------------------------------------
* 11.6 P5-P95 range for marginal-effect figures
*------------------------------------------------------------

summ c_lag if sample_weekly == 1, detail

local p5  = r(p5)
local p95 = r(p95)

display "P5  = " `p5'
display "P95 = " `p95'


*------------------------------------------------------------
* 11.7 Loudness marginal-effect figure
*------------------------------------------------------------

estimates restore revised_joint

margins, dydx(nov_loud) ///
    at(c_lag=(-2.110836(.15)1.538256)) ///
    post

marginsplot, ///
    recast(line) ///
    recastci(rarea) ///
    yline(0, lpattern(dash)) ///
    xline(-1.110257, lpattern(shortdash)) ///
    xtitle("Centered log prior-week streams") ///
    ytitle("Marginal association of loudness") ///
    title("State-dependent association of loudness") ///
    legend(off) ///
    name(g_loud, replace)


*------------------------------------------------------------
* 11.8 Onset-rate marginal-effect figure
*------------------------------------------------------------

estimates restore revised_joint

margins, dydx(nov_onset) ///
    at(c_lag=(-2.110836(.15)1.538256)) ///
    post

marginsplot, ///
    recast(line) ///
    recastci(rarea) ///
    yline(0, lpattern(dash)) ///
    xline(-1.054223, lpattern(shortdash)) ///
    xtitle("Centered log prior-week streams") ///
    ytitle("Marginal association of onset rate") ///
    title("State-dependent association of onset rate") ///
    legend(off) ///
    name(g_onset, replace)


display "============================================================"
display "FEATURE-SPECIFIC AND MARGINAL-EFFECT BLOCK COMPLETED"
display "============================================================"

*------------------------------------------------------------
* 11.9 Flexible functional-form check: restricted cubic spline
*      Reviewer request: assess the linearity assumption
*------------------------------------------------------------

* Four knots: P10, P35, P65, P90 of centered prior-week popularity
mkspline spl = c_lag if sample_weekly == 1, ///
    cubic knots(-1.7288179 -0.06886946 0.43659806 1.2063851)

* Joint spline specification
reg log_streams_check ///
    spl1 spl2 spl3 ///
    nov_dance nov_loud nov_complex nov_onset ///
    c.nov_dance#c.spl1 c.nov_dance#c.spl2 c.nov_dance#c.spl3 ///
    c.nov_loud#c.spl1 c.nov_loud#c.spl2 c.nov_loud#c.spl3 ///
    c.nov_complex#c.spl1 c.nov_complex#c.spl2 c.nov_complex#c.spl3 ///
    c.nov_onset#c.spl1 c.nov_onset#c.spl2 c.nov_onset#c.spl3 ///
    i.week_fe ///
    if sample_weekly == 1, ///
    vce(cluster track_num)

estimates store spline_joint

display "============================================================"
display "RESTRICTED CUBIC SPLINE MODEL"
display "Expected R2   ≈ 0.9714"
display "Expected RMSE ≈ 0.18026"
display "============================================================"

* Test nonlinear interaction components for each feature
test ///
    c.nov_dance#c.spl2 ///
    c.nov_dance#c.spl3
display "Expected Danceability nonlinear test: F ≈ 3.75, p ≈ 0.024"

test ///
    c.nov_loud#c.spl2 ///
    c.nov_loud#c.spl3
display "Expected Loudness nonlinear test: F ≈ 1.75, p ≈ 0.173"

test ///
    c.nov_complex#c.spl2 ///
    c.nov_complex#c.spl3
display "Expected Complexity nonlinear test: F ≈ 2.31, p ≈ 0.099"

test ///
    c.nov_onset#c.spl2 ///
    c.nov_onset#c.spl3
display "Expected Onset-rate nonlinear test: F ≈ 5.37, p ≈ 0.005"

* Joint test of all eight nonlinear interaction components
test ///
    c.nov_dance#c.spl2 c.nov_dance#c.spl3 ///
    c.nov_loud#c.spl2 c.nov_loud#c.spl3 ///
    c.nov_complex#c.spl2 c.nov_complex#c.spl3 ///
    c.nov_onset#c.spl2 c.nov_onset#c.spl3

display "Expected joint nonlinear test: F(8,6230) ≈ 3.30, p < 0.001"

*------------------------------------------------------------
* 11.10 Linear-versus-spline comparison figures
*       Reviewer request: visualize flexible functional form
*------------------------------------------------------------

preserve

clear
set obs 100

* Evaluation grid over the central empirical support
gen double c_lag_grid = ///
    -1.7288179 + (_n-1) * ///
    (1.2063851 - (-1.7288179)) / 99

* Reconstruct spline basis on the evaluation grid
mkspline spl = c_lag_grid, ///
    cubic knots(-1.7288179 -0.06886946 0.43659806 1.2063851)


*------------------------------------------------------------
* Onset rate: spline marginal association
*------------------------------------------------------------

estimates restore spline_joint

gen double onset_spline = ///
    _b[nov_onset] + ///
    _b[c.nov_onset#c.spl1] * spl1 + ///
    _b[c.nov_onset#c.spl2] * spl2 + ///
    _b[c.nov_onset#c.spl3] * spl3


* Linear specification
estimates restore revised_joint

gen double onset_linear = ///
    _b[nov_onset] + ///
    _b[c.nov_onset#c.c_lag] * c_lag_grid


twoway ///
    (line onset_linear c_lag_grid) ///
    (line onset_spline c_lag_grid), ///
    yline(0, lpattern(dash)) ///
    xtitle("Centered log prior-week streams") ///
    ytitle("Marginal association of onset rate") ///
    legend(order(1 "Linear" 2 "Restricted cubic spline")) ///
    title("Onset rate: linear versus spline specification") ///
    name(g_onset_spline, replace)

graph export ///
    "output/linearvsspline.png", ///
    width(2400) replace


*------------------------------------------------------------
* Loudness: spline marginal association
*------------------------------------------------------------

estimates restore spline_joint

gen double loud_spline = ///
    _b[nov_loud] + ///
    _b[c.nov_loud#c.spl1] * spl1 + ///
    _b[c.nov_loud#c.spl2] * spl2 + ///
    _b[c.nov_loud#c.spl3] * spl3


* Linear specification
estimates restore revised_joint

gen double loud_linear = ///
    _b[nov_loud] + ///
    _b[c.nov_loud#c.c_lag] * c_lag_grid


twoway ///
    (line loud_linear c_lag_grid) ///
    (line loud_spline c_lag_grid), ///
    yline(0, lpattern(dash)) ///
    xtitle("Centered log prior-week streams") ///
    ytitle("Marginal association of loudness") ///
    legend(order(1 "Linear" 2 "Restricted cubic spline")) ///
    title("Loudness: linear versus spline specification") ///
    name(g_loud_spline, replace)

graph export ///
    "output/linearvsspline2.png", ///
    width(2400) replace

restore

*==========================================================================
* 12. ROBUSTNESS: RECCOBEATS-ONLY SAMPLE
*==========================================================================

display "============================================================"
display "SECTION 12 - RECCOBEATS ROBUSTNESS"
display "============================================================"

preserve

keep if sample_weekly == 1
keep if af_source == "reccobeats"

count
display "Expected observations: 73917"

capture drop tag_track_recco
egen tag_track_recco = tag(track_num)
count if tag_track_recco == 1
display "Expected tracks: 4206"

*------------------------------------------------------------
* 12.1 Reccobeats only - original full-market benchmarks
*------------------------------------------------------------

reg log_streams_check ///
    c_lag ///
    nov_dance nov_loud nov_complex nov_onset ///
    c.nov_dance#c.c_lag ///
    c.nov_loud#c.c_lag ///
    c.nov_complex#c.c_lag ///
    c.nov_onset#c.c_lag ///
    i.week_fe, ///
    vce(cluster track_num)

estimates store recco_joint


* Feature-specific loudness
reg log_streams_check ///
    c_lag nov_loud ///
    c.nov_loud#c.c_lag ///
    i.week_fe, ///
    vce(cluster track_num)

estimates store recco_loud


*------------------------------------------------------------
* 12.2 Strict Reccobeats benchmarks
*      Weekly means recomputed inside Reccobeats sample
*------------------------------------------------------------

bysort week: egen mean_dance_recco = mean(af_danceability)
gen nov_dance_recco = af_danceability - mean_dance_recco

bysort week: egen mean_loud_recco = mean(af_loudness)
gen nov_loud_recco = af_loudness - mean_loud_recco

summ nov_dance_recco nov_loud_recco


* Joint strict-Reccobeats model
reg log_streams_check ///
    c_lag ///
    nov_dance_recco nov_loud_recco nov_complex nov_onset ///
    c.nov_dance_recco#c.c_lag ///
    c.nov_loud_recco#c.c_lag ///
    c.nov_complex#c.c_lag ///
    c.nov_onset#c.c_lag ///
    i.week_fe, ///
    vce(cluster track_num)

estimates store recco_strict_joint


* Danceability only
reg log_streams_check ///
    c_lag nov_dance_recco ///
    c.nov_dance_recco#c.c_lag ///
    i.week_fe, ///
    vce(cluster track_num)

estimates store recco_strict_dance


* Loudness only
reg log_streams_check ///
    c_lag nov_loud_recco ///
    c.nov_loud_recco#c.c_lag ///
    i.week_fe, ///
    vce(cluster track_num)

estimates store recco_strict_loud


* Correlation diagnostics
pwcorr nov_dance_recco nov_loud_recco ///
       nov_complex nov_onset, sig obs

reg nov_dance_recco ///
    nov_loud_recco nov_complex nov_onset

restore


*==========================================================================
* 13. ROBUSTNESS: TRACK FIXED EFFECTS
*==========================================================================

display "============================================================"
display "SECTION 13 - TRACK FIXED EFFECTS"
display "============================================================"

*------------------------------------------------------------
* 13.1 Absorbed track fixed effects
*------------------------------------------------------------

areg log_streams_check ///
    c_lag ///
    c.nov_dance#c.c_lag ///
    c.nov_loud#c.c_lag ///
    c.nov_complex#c.c_lag ///
    c.nov_onset#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    absorb(track_num) vce(cluster track_num)

estimates store trackFE_joint


* Feature-specific track FE models

areg log_streams_check ///
    c_lag ///
    c.nov_dance#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    absorb(track_num) vce(cluster track_num)

estimates store trackFE_dance


areg log_streams_check ///
    c_lag ///
    c.nov_loud#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    absorb(track_num) vce(cluster track_num)

estimates store trackFE_loud


areg log_streams_check ///
    c_lag ///
    c.nov_complex#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    absorb(track_num) vce(cluster track_num)

estimates store trackFE_complex


areg log_streams_check ///
    c_lag ///
    c.nov_onset#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    absorb(track_num) vce(cluster track_num)

estimates store trackFE_onset


*------------------------------------------------------------
* 13.2 Within estimator
*------------------------------------------------------------

xtset track_num week

xtreg log_streams_check ///
    c_lag ///
    c.nov_dance#c.c_lag ///
    c.nov_loud#c.c_lag ///
    c.nov_complex#c.c_lag ///
    c.nov_onset#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    fe vce(cluster track_num)

estimates store xtFE_joint


xtreg log_streams_check ///
    c_lag ///
    c.nov_dance#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    fe vce(cluster track_num)

estimates store xtFE_dance


xtreg log_streams_check ///
    c_lag ///
    c.nov_loud#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    fe vce(cluster track_num)

estimates store xtFE_loud


xtreg log_streams_check ///
    c_lag ///
    c.nov_complex#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    fe vce(cluster track_num)

estimates store xtFE_complex


xtreg log_streams_check ///
    c_lag ///
    c.nov_onset#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    fe vce(cluster track_num)

estimates store xtFE_onset


*==========================================================================
* 14. ROBUSTNESS: PREVIOUS OBSERVED CHART APPEARANCE
*==========================================================================

display "============================================================"
display "SECTION 14 - ALTERNATIVE LAG DEFINITION"
display "============================================================"

summ lag_prevobs if sample_prevobs == 1, meanonly

scalar mean_lag_prevobs = r(mean)

capture drop c_lag_prevobs

gen double c_lag_prevobs = ///
    lag_prevobs - mean_lag_prevobs ///
    if sample_prevobs == 1


reg log_streams_check ///
    c_lag_prevobs ///
    nov_dance nov_loud nov_complex nov_onset ///
    c.nov_dance#c.c_lag_prevobs ///
    c.nov_loud#c.c_lag_prevobs ///
    c.nov_complex#c.c_lag_prevobs ///
    c.nov_onset#c.c_lag_prevobs ///
    i.week_fe ///
    if sample_prevobs == 1, ///
    vce(cluster track_num)

estimates store prevobs_joint


* Exit / re-entry diagnostics
count if sample_prevobs == 1 & gap_days == 7
display "Expected exact-week cases: 104986"

count if sample_prevobs == 1 & gap_days > 7
display "Expected non-consecutive cases: 4358"

summ gap_days ///
    if sample_prevobs == 1 & gap_days > 7, detail


*==========================================================================
* 15. ROBUSTNESS: LEAVE-ONE-OUT WEEKLY BENCHMARKS
*==========================================================================

display "============================================================"
display "SECTION 15 - LEAVE-ONE-OUT BENCHMARKS"
display "============================================================"

* Danceability
bysort week: egen double sum_dance_week = total(af_danceability)
bysort week: egen n_dance_week = count(af_danceability)

gen double mean_dance_loo = ///
    (sum_dance_week - af_danceability) / ///
    (n_dance_week - 1) ///
    if !missing(af_danceability) & n_dance_week > 1

gen double nov_dance_loo = ///
    af_danceability - mean_dance_loo


* Loudness
bysort week: egen double sum_loud_week = total(af_loudness)
bysort week: egen n_loud_week = count(af_loudness)

gen double mean_loud_loo = ///
    (sum_loud_week - af_loudness) / ///
    (n_loud_week - 1) ///
    if !missing(af_loudness) & n_loud_week > 1

gen double nov_loud_loo = ///
    af_loudness - mean_loud_loo


* Complexity
bysort week: egen double sum_complex_week = ///
    total(es_dynamic_complexity)

bysort week: egen n_complex_week = ///
    count(es_dynamic_complexity)

gen double mean_complex_loo = ///
    (sum_complex_week - es_dynamic_complexity) / ///
    (n_complex_week - 1) ///
    if !missing(es_dynamic_complexity) & n_complex_week > 1

gen double nov_complex_loo = ///
    es_dynamic_complexity - mean_complex_loo


* Onset rate
bysort week: egen double sum_onset_week = ///
    total(es_onset_rate)

bysort week: egen n_onset_week = ///
    count(es_onset_rate)

gen double mean_onset_loo = ///
    (sum_onset_week - es_onset_rate) / ///
    (n_onset_week - 1) ///
    if !missing(es_onset_rate) & n_onset_week > 1

gen double nov_onset_loo = ///
    es_onset_rate - mean_onset_loo


* Correlation with original construction
corr nov_dance nov_dance_loo if sample_weekly == 1
corr nov_loud nov_loud_loo if sample_weekly == 1
corr nov_complex nov_complex_loo if sample_weekly == 1
corr nov_onset nov_onset_loo if sample_weekly == 1


reg log_streams_check ///
    c_lag ///
    nov_dance_loo nov_loud_loo nov_complex_loo nov_onset_loo ///
    c.nov_dance_loo#c.c_lag ///
    c.nov_loud_loo#c.c_lag ///
    c.nov_complex_loo#c.c_lag ///
    c.nov_onset_loo#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1, ///
    vce(cluster track_num)

estimates store loo_joint


*==========================================================================
* 16. ROBUSTNESS: ALTERNATIVE TIME FIXED EFFECTS
*==========================================================================

display "============================================================"
display "SECTION 16 - ALTERNATIVE TIME FIXED EFFECTS"
display "============================================================"

reg log_streams_check ///
    c_lag ///
    nov_dance nov_loud nov_complex nov_onset ///
    c.nov_dance#c.c_lag ///
    c.nov_loud#c.c_lag ///
    c.nov_complex#c.c_lag ///
    c.nov_onset#c.c_lag ///
    i.year i.month ///
    if sample_weekly == 1, ///
    vce(cluster track_num)

estimates store yearmonth_joint


* Baseline week-FE model already stored as revised_joint


*==========================================================================
* 17. ROBUSTNESS: TOP-200 CHART RESTRICTION
*==========================================================================

display "============================================================"
display "SECTION 17 - POSITION <= 200"
display "============================================================"

preserve

keep if position <= 200

sort track_num week

capture drop gap_days_200 lag_weekly_200

bysort track_num (week): ///
    gen gap_days_200 = week - week[_n-1]

bysort track_num (week): ///
    gen double lag_weekly_200 = ///
    log_streams_check[_n-1] if gap_days_200 == 7

capture drop sample_200

gen byte sample_200 = ///
    !missing(lag_weekly_200) & ///
    !missing(nov_dance, nov_loud, nov_complex, nov_onset)

count if sample_200 == 1
display "Expected Top-200 estimation sample: 104543"

summ lag_weekly_200 if sample_200 == 1, meanonly

scalar mean_lag_200 = r(mean)

gen double c_lag_200 = ///
    lag_weekly_200 - mean_lag_200 ///
    if sample_200 == 1

capture drop week_fe_200
egen week_fe_200 = group(week)


reg log_streams_check ///
    c_lag_200 ///
    nov_dance nov_loud nov_complex nov_onset ///
    c.nov_dance#c.c_lag_200 ///
    c.nov_loud#c.c_lag_200 ///
    c.nov_complex#c.c_lag_200 ///
    c.nov_onset#c.c_lag_200 ///
    i.week_fe_200 ///
    if sample_200 == 1, ///
    vce(cluster track_num)

estimates store top200_joint

restore


*==========================================================================
* 18. ROBUSTNESS: SOURCE-STANDARDIZED AF FEATURES
*     TRACK-LEVEL STANDARDIZATION
*==========================================================================

display "============================================================"
display "SECTION 18 - SOURCE-STANDARDIZED FEATURES (TRACK LEVEL)"
display "============================================================"

preserve

keep if sample_weekly == 1

*------------------------------------------------------------
* 18.1 Identify one observation per track
*------------------------------------------------------------

capture drop tag_track_src

egen tag_track_src = tag(track_num)

count if tag_track_src == 1
display "Expected unique tracks in revised sample: 6231"


*------------------------------------------------------------
* 18.2 Track-level source distributions
*------------------------------------------------------------

tabstat af_danceability af_loudness ///
    if tag_track_src == 1, ///
    by(af_source) ///
    statistics(n mean sd p25 p50 p75 min max) ///
    columns(statistics)


*------------------------------------------------------------
* 18.3 Compute source-specific TRACK-LEVEL means and SDs
*------------------------------------------------------------

capture drop ///
    mean_dance_src_trk sd_dance_src_trk ///
    mean_loud_src_trk sd_loud_src_trk

gen double mean_dance_src_trk = .
gen double sd_dance_src_trk   = .

gen double mean_loud_src_trk  = .
gen double sd_loud_src_trk    = .


levelsof af_source if tag_track_src == 1, local(sources)

foreach s of local sources {

    quietly summarize af_danceability ///
        if tag_track_src == 1 & af_source == "`s'"

    replace mean_dance_src_trk = r(mean) ///
        if af_source == "`s'"

    replace sd_dance_src_trk = r(sd) ///
        if af_source == "`s'"


    quietly summarize af_loudness ///
        if tag_track_src == 1 & af_source == "`s'"

    replace mean_loud_src_trk = r(mean) ///
        if af_source == "`s'"

    replace sd_loud_src_trk = r(sd) ///
        if af_source == "`s'"
}


*------------------------------------------------------------
* 18.4 Standardize raw AF features using track-level
*      source-specific parameters
*------------------------------------------------------------

capture drop z_dance_src_trk z_loud_src_trk

gen double z_dance_src_trk = ///
    (af_danceability - mean_dance_src_trk) / ///
    sd_dance_src_trk

gen double z_loud_src_trk = ///
    (af_loudness - mean_loud_src_trk) / ///
    sd_loud_src_trk


* Verify that TRACK-LEVEL distributions are standardized
tabstat z_dance_src_trk z_loud_src_trk ///
    if tag_track_src == 1, ///
    by(af_source) ///
    statistics(n mean sd) ///
    columns(statistics)


*------------------------------------------------------------
* 18.5 Construct weekly deviations after source
*      standardization
*------------------------------------------------------------

capture drop ///
    mean_zdance_week_trk nov_dance_srcstd_trk ///
    mean_zloud_week_trk nov_loud_srcstd_trk

bysort week: egen double mean_zdance_week_trk = ///
    mean(z_dance_src_trk)

gen double nov_dance_srcstd_trk = ///
    z_dance_src_trk - mean_zdance_week_trk


bysort week: egen double mean_zloud_week_trk = ///
    mean(z_loud_src_trk)

gen double nov_loud_srcstd_trk = ///
    z_loud_src_trk - mean_zloud_week_trk


summ nov_dance_srcstd_trk nov_loud_srcstd_trk


*------------------------------------------------------------
* 18.6 Joint source-standardized robustness model
*------------------------------------------------------------

reg log_streams_check ///
    c_lag ///
    nov_dance_srcstd_trk ///
    nov_loud_srcstd_trk ///
    nov_complex ///
    nov_onset ///
    c.nov_dance_srcstd_trk#c.c_lag ///
    c.nov_loud_srcstd_trk#c.c_lag ///
    c.nov_complex#c.c_lag ///
    c.nov_onset#c.c_lag ///
    i.week_fe, ///
    vce(cluster track_num)

estimates store source_std_track_joint


display "============================================================"
display "TRACK-LEVEL SOURCE STANDARDIZATION COMPLETED"
display "============================================================"

restore


*==========================================================================
* 19. ROBUSTNESS: WITHIN-WEEK STANDARDIZED NOVELTY
*==========================================================================

display "============================================================"
display "SECTION 19 - WEEKLY STANDARDIZED NOVELTY"
display "============================================================"

preserve

keep if sample_weekly == 1

* Danceability
bysort week: egen mean_dance_w = mean(af_danceability)
bysort week: egen sd_dance_w   = sd(af_danceability)

gen double znov_dance = ///
    (af_danceability - mean_dance_w) / sd_dance_w


* Loudness
bysort week: egen mean_loud_w = mean(af_loudness)
bysort week: egen sd_loud_w   = sd(af_loudness)

gen double znov_loud = ///
    (af_loudness - mean_loud_w) / sd_loud_w


* Complexity
bysort week: egen mean_complex_w = ///
    mean(es_dynamic_complexity)

bysort week: egen sd_complex_w = ///
    sd(es_dynamic_complexity)

gen double znov_complex = ///
    (es_dynamic_complexity - mean_complex_w) / sd_complex_w


* Onset rate
bysort week: egen mean_onset_w = mean(es_onset_rate)
bysort week: egen sd_onset_w   = sd(es_onset_rate)

gen double znov_onset = ///
    (es_onset_rate - mean_onset_w) / sd_onset_w


summ znov_dance znov_loud znov_complex znov_onset


reg log_streams_check ///
    c_lag ///
    znov_dance znov_loud znov_complex znov_onset ///
    c.znov_dance#c.c_lag ///
    c.znov_loud#c.c_lag ///
    c.znov_complex#c.c_lag ///
    c.znov_onset#c.c_lag ///
    i.week_fe, ///
    vce(cluster track_num)

estimates store weekly_z_joint

restore


display "============================================================"
display "ALL CORE ROBUSTNESS CHECKS COMPLETED"
display "============================================================"

*==========================================================================
* 20. ROBUSTNESS: MINIMUM USABLE TRACK HISTORIES
*     Reviewer request: assess sensitivity to short track histories
*==========================================================================

display "============================================================"
display "SECTION 20 - MINIMUM USABLE TRACK HISTORIES"
display "============================================================"

* Number of usable exact-week-lag observations contributed by each track
capture drop n_usable_track
bysort track_num: egen n_usable_track = total(sample_weekly == 1)


*------------------------------------------------------------
* 20.1 Require at least 4 usable exact-week-lag observations
*------------------------------------------------------------

count if sample_weekly == 1 & n_usable_track >= 4
display "Expected observations with >=4 usable observations: 101428"

capture drop tag_min4
egen tag_min4 = tag(track_num) if sample_weekly == 1 & n_usable_track >= 4

count if tag_min4 == 1
display "Expected tracks with >=4 usable observations: 4162"

reg log_streams_check ///
    c_lag ///
    nov_dance nov_loud nov_complex nov_onset ///
    c.nov_dance#c.c_lag ///
    c.nov_loud#c.c_lag ///
    c.nov_complex#c.c_lag ///
    c.nov_onset#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1 & n_usable_track >= 4, ///
    vce(cluster track_num)

estimates store min4_joint

display "Expected interactions:"
display "Danceability ≈  0.003186"
display "Loudness     ≈  0.0007778"
display "Complexity   ≈  0.0001884"
display "Onset rate   ≈ -0.0061411"


*------------------------------------------------------------
* 20.2 Require at least 8 usable exact-week-lag observations
*------------------------------------------------------------

count if sample_weekly == 1 & n_usable_track >= 8
display "Expected observations with >=8 usable observations: 96175"

capture drop tag_min8
egen tag_min8 = tag(track_num) if sample_weekly == 1 & n_usable_track >= 8

count if tag_min8 == 1
display "Expected tracks with >=8 usable observations: 3168"

reg log_streams_check ///
    c_lag ///
    nov_dance nov_loud nov_complex nov_onset ///
    c.nov_dance#c.c_lag ///
    c.nov_loud#c.c_lag ///
    c.nov_complex#c.c_lag ///
    c.nov_onset#c.c_lag ///
    i.week_fe ///
    if sample_weekly == 1 & n_usable_track >= 8, ///
    vce(cluster track_num)

estimates store min8_joint

display "Expected interactions:"
display "Danceability ≈ -0.0003476"
display "Loudness     ≈  0.0005681"
display "Complexity   ≈  0.0002952"
display "Onset rate   ≈ -0.0051137"

display "============================================================"
display "MINIMUM-HISTORY ROBUSTNESS CHECKS COMPLETED"
display "============================================================"

*==========================================================================
* 21. EXPORT FINAL TABLES
*==========================================================================

display "============================================================"
display "SECTION 20 - EXPORT FINAL TABLES"
display "============================================================"

* Create portable output directory
capture mkdir "output"


*==========================================================================
* 21.1 MAIN JOINT MODEL TABLE
*==========================================================================

tempname mainpost
tempfile maintable

postfile `mainpost' ///
    str40 variable ///
    double coefficient se pvalue ///
    using `maintable', replace

estimates restore revised_joint

local df = e(df_r)

foreach v in ///
    c_lag ///
    nov_dance ///
    nov_loud ///
    nov_complex ///
    nov_onset ///
    c.nov_dance#c.c_lag ///
    c.nov_loud#c.c_lag ///
    c.nov_complex#c.c_lag ///
    c.nov_onset#c.c_lag {

    scalar __b  = _b[`v']
    scalar __se = _se[`v']
    scalar __p  = 2*ttail(`df',abs(__b/__se))

    post `mainpost' ///
        ("`v'") ///
        (__b) ///
        (__se) ///
        (__p)
}

postclose `mainpost'


preserve

use `maintable', clear

format coefficient se %9.6f
format pvalue %9.4f

export delimited using ///
    "output/table_main_joint.csv", ///
    replace



restore

*==========================================================================
* 21.2 SAMPLE-SELECTION DIAGNOSTICS
*==========================================================================

preserve

import delimited using ///
    "output/sample_selection_track_level.csv", ///
    clear

export excel using ///
    "output/final_tables.xlsx", ///
    sheet("Sample selection") ///
    firstrow(variables) ///
    sheetreplace

restore

*==========================================================================
* 21.3 BENCHMARK MODEL COMPARISON
*     Reviewer request: compare persistence-only and full model fit
*==========================================================================

tempname benchpost
tempfile benchtable

postfile `benchpost' ///
    str30 model ///
    double r2 adj_r2 rmse ///
    using `benchtable', replace


* Persistence-only benchmark
estimates restore persistence_benchmark

post `benchpost' ///
    ("Lag + week FE") ///
    (e(r2)) ///
    (e(r2_a)) ///
    (e(rmse))


* Full preferred model
estimates restore revised_joint

post `benchpost' ///
    ("Full joint model") ///
    (e(r2)) ///
    (e(r2_a)) ///
    (e(rmse))

postclose `benchpost'


preserve

use `benchtable', clear

format r2 adj_r2 rmse %9.6f

list, noobs clean

export delimited using ///
    "output/table_benchmark_comparison.csv", ///
    replace

export excel using ///
    "output/final_tables.xlsx", ///
    sheet("Benchmark comparison") ///
    firstrow(variables) ///
    sheetreplace

restore

*==========================================================================
* 21.4 PRACTICAL EFFECT-SIZE TABLE
*     Reviewer request: express associations as percentage
*     differences in weekly streams for a +1 SD feature change
*==========================================================================

tempname practicalpost
tempfile practicaltable

postfile `practicalpost' ///
    str20 feature ///
    str10 popularity ///
    double pct_difference ///
    using `practicaltable', replace


* Loudness
post `practicalpost' ///
    ("Loudness") ("P25") (loud_pct_p25)

post `practicalpost' ///
    ("Loudness") ("P50") (loud_pct_p50)

post `practicalpost' ///
    ("Loudness") ("P75") (loud_pct_p75)


* Onset rate
post `practicalpost' ///
    ("Onset rate") ("P25") (onset_pct_p25)

post `practicalpost' ///
    ("Onset rate") ("P50") (onset_pct_p50)

post `practicalpost' ///
    ("Onset rate") ("P75") (onset_pct_p75)

postclose `practicalpost'


preserve

use `practicaltable', clear

format pct_difference %9.3f

list, noobs clean

export delimited using ///
    "output/table_practical_effects.csv", ///
    replace

export excel using ///
    "output/final_tables.xlsx", ///
    sheet("Practical effects") ///
    firstrow(variables) ///
    sheetreplace

restore

*==========================================================================
* 21.5 ZERO-CROSSING TABLE
*     Reviewer request: report coefficient ratios only when
*     interaction terms are sufficiently precise
*==========================================================================

tempname zeropost
tempfile zerotable

postfile `zeropost' ///
    str20 feature ///
    double zero_crossing se ci_low ci_high ///
    using `zerotable', replace


*------------------------------------------------------------
* Loudness
*------------------------------------------------------------

estimates restore revised_joint
scalar df_zero = e(df_r)

nlcom (loud_zero: ///
    -_b[nov_loud] / _b[c.nov_loud#c.c_lag]), post

scalar z_b  = _b[loud_zero]
scalar z_se = _se[loud_zero]
scalar z_cv = invttail(df_zero, 0.025)

scalar z_lo = z_b - z_cv*z_se
scalar z_hi = z_b + z_cv*z_se

post `zeropost' ///
    ("Loudness") ///
    (z_b) ///
    (z_se) ///
    (z_lo) ///
    (z_hi)


*------------------------------------------------------------
* Onset rate
*------------------------------------------------------------

estimates restore revised_joint

nlcom (onset_zero: ///
    -_b[nov_onset] / _b[c.nov_onset#c.c_lag]), post

scalar z_b  = _b[onset_zero]
scalar z_se = _se[onset_zero]

scalar z_lo = z_b - z_cv*z_se
scalar z_hi = z_b + z_cv*z_se

post `zeropost' ///
    ("Onset rate") ///
    (z_b) ///
    (z_se) ///
    (z_lo) ///
    (z_hi)

postclose `zeropost'


preserve

use `zerotable', clear

format zero_crossing se ci_low ci_high %9.3f

list, noobs clean

export delimited using ///
    "output/table_zero_crossings.csv", ///
    replace

export excel using ///
    "output/final_tables.xlsx", ///
    sheet("Zero crossings") ///
    firstrow(variables) ///
    sheetreplace

restore

* Restore preferred model for subsequent calculations
estimates restore revised_joint

*==========================================================================
* 21.6 EMPIRICAL SUPPORT AROUND ZERO-CROSSINGS
*==========================================================================

tempname supportpost
tempfile supporttable

postfile `supportpost' ///
    str20 feature ///
    double zero_crossing ///
    long n_below n_above ///
    double pct_below pct_above ///
    using `supporttable', replace


*------------------------------------------------------------
* Loudness
*------------------------------------------------------------

quietly count if ///
    sample_weekly == 1 & ///
    c_lag < -1.110257

scalar loud_n_below = r(N)

quietly count if ///
    sample_weekly == 1 & ///
    c_lag >= -1.110257

scalar loud_n_above = r(N)

scalar loud_total = loud_n_below + loud_n_above

scalar loud_pct_below = ///
    100*loud_n_below/loud_total

scalar loud_pct_above = ///
    100*loud_n_above/loud_total

post `supportpost' ///
    ("Loudness") ///
    (-1.110257) ///
    (loud_n_below) ///
    (loud_n_above) ///
    (loud_pct_below) ///
    (loud_pct_above)


*------------------------------------------------------------
* Onset rate
*------------------------------------------------------------

quietly count if ///
    sample_weekly == 1 & ///
    c_lag < -1.054223

scalar onset_n_below = r(N)

quietly count if ///
    sample_weekly == 1 & ///
    c_lag >= -1.054223

scalar onset_n_above = r(N)

scalar onset_total = onset_n_below + onset_n_above

scalar onset_pct_below = ///
    100*onset_n_below/onset_total

scalar onset_pct_above = ///
    100*onset_n_above/onset_total

post `supportpost' ///
    ("Onset rate") ///
    (-1.054223) ///
    (onset_n_below) ///
    (onset_n_above) ///
    (onset_pct_below) ///
    (onset_pct_above)

postclose `supportpost'


preserve

use `supporttable', clear

format zero_crossing %9.3f
format pct_below pct_above %9.1f

list, noobs clean

export delimited using ///
    "output/table_zero_crossing_support.csv", ///
    replace

export excel using ///
    "output/final_tables.xlsx", ///
    sheet("Zero support") ///
    firstrow(variables) ///
    sheetreplace

restore

*==========================================================================
* 21.7 FEATURE-SPECIFIC MODELS
*==========================================================================

tempname fspost
tempfile fstable

postfile `fspost' ///
    str20 feature ///
    double main_b main_se main_p ///
    interaction_b interaction_se interaction_p ///
    using `fstable', replace


* Danceability
estimates restore fs_dance

scalar b1  = _b[nov_dance]
scalar se1 = _se[nov_dance]
scalar p1  = 2*ttail(e(df_r),abs(b1/se1))

scalar b2  = _b[c.nov_dance#c.c_lag]
scalar se2 = _se[c.nov_dance#c.c_lag]
scalar p2  = 2*ttail(e(df_r),abs(b2/se2))

post `fspost' ("Danceability") ///
    (b1) (se1) (p1) ///
    (b2) (se2) (p2)


* Loudness
estimates restore fs_loud

scalar b1  = _b[nov_loud]
scalar se1 = _se[nov_loud]
scalar p1  = 2*ttail(e(df_r),abs(b1/se1))

scalar b2  = _b[c.nov_loud#c.c_lag]
scalar se2 = _se[c.nov_loud#c.c_lag]
scalar p2  = 2*ttail(e(df_r),abs(b2/se2))

post `fspost' ("Loudness") ///
    (b1) (se1) (p1) ///
    (b2) (se2) (p2)


* Dynamic complexity
estimates restore fs_complex

scalar b1  = _b[nov_complex]
scalar se1 = _se[nov_complex]
scalar p1  = 2*ttail(e(df_r),abs(b1/se1))

scalar b2  = _b[c.nov_complex#c.c_lag]
scalar se2 = _se[c.nov_complex#c.c_lag]
scalar p2  = 2*ttail(e(df_r),abs(b2/se2))

post `fspost' ("Complexity") ///
    (b1) (se1) (p1) ///
    (b2) (se2) (p2)


* Onset rate
estimates restore fs_onset

scalar b1  = _b[nov_onset]
scalar se1 = _se[nov_onset]
scalar p1  = 2*ttail(e(df_r),abs(b1/se1))

scalar b2  = _b[c.nov_onset#c.c_lag]
scalar se2 = _se[c.nov_onset#c.c_lag]
scalar p2  = 2*ttail(e(df_r),abs(b2/se2))

post `fspost' ("Onset rate") ///
    (b1) (se1) (p1) ///
    (b2) (se2) (p2)

postclose `fspost'


preserve

use `fstable', clear

format main_b main_se interaction_b interaction_se %9.6f
format main_p interaction_p %9.4f

export delimited using ///
    "output/table_feature_specific.csv", ///
    replace

export excel using ///
    "output/final_tables.xlsx", ///
    sheet("Feature specific") ///
    firstrow(variables) ///
    sheetreplace

restore


*==========================================================================
* 21.8 ROBUSTNESS MATRIX
*
* Each row reports the four state-dependence interaction coefficients
* and their p-values.
*==========================================================================

tempname robpost
tempfile robtable

postfile `robpost' ///
    str35 specification ///
    double dance_b dance_p ///
    loud_b loud_p ///
    complex_b complex_p ///
    onset_b onset_p ///
    using `robtable', replace


*-----------------------------------------------------------------------
* Revised baseline
*-----------------------------------------------------------------------

estimates restore revised_joint

scalar db = _b[c.nov_dance#c.c_lag]
scalar dp = 2*ttail(e(df_r),abs(db/_se[c.nov_dance#c.c_lag]))

scalar lb = _b[c.nov_loud#c.c_lag]
scalar lp = 2*ttail(e(df_r),abs(lb/_se[c.nov_loud#c.c_lag]))

scalar cb = _b[c.nov_complex#c.c_lag]
scalar cp = 2*ttail(e(df_r),abs(cb/_se[c.nov_complex#c.c_lag]))

scalar ob = _b[c.nov_onset#c.c_lag]
scalar op = 2*ttail(e(df_r),abs(ob/_se[c.nov_onset#c.c_lag]))

post `robpost' ("Revised baseline") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)


*-----------------------------------------------------------------------
* Feature-specific
*-----------------------------------------------------------------------

estimates restore fs_dance
scalar db = _b[c.nov_dance#c.c_lag]
scalar dp = 2*ttail(e(df_r),abs(db/_se[c.nov_dance#c.c_lag]))

estimates restore fs_loud
scalar lb = _b[c.nov_loud#c.c_lag]
scalar lp = 2*ttail(e(df_r),abs(lb/_se[c.nov_loud#c.c_lag]))

estimates restore fs_complex
scalar cb = _b[c.nov_complex#c.c_lag]
scalar cp = 2*ttail(e(df_r),abs(cb/_se[c.nov_complex#c.c_lag]))

estimates restore fs_onset
scalar ob = _b[c.nov_onset#c.c_lag]
scalar op = 2*ttail(e(df_r),abs(ob/_se[c.nov_onset#c.c_lag]))

post `robpost' ("Feature-specific") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)


*-----------------------------------------------------------------------
* Reccobeats only
*-----------------------------------------------------------------------

estimates restore recco_joint

scalar db = _b[c.nov_dance#c.c_lag]
scalar dp = 2*ttail(e(df_r),abs(db/_se[c.nov_dance#c.c_lag]))

scalar lb = _b[c.nov_loud#c.c_lag]
scalar lp = 2*ttail(e(df_r),abs(lb/_se[c.nov_loud#c.c_lag]))

scalar cb = _b[c.nov_complex#c.c_lag]
scalar cp = 2*ttail(e(df_r),abs(cb/_se[c.nov_complex#c.c_lag]))

scalar ob = _b[c.nov_onset#c.c_lag]
scalar op = 2*ttail(e(df_r),abs(ob/_se[c.nov_onset#c.c_lag]))

post `robpost' ("Reccobeats only") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)


*-----------------------------------------------------------------------
* Strict Reccobeats
*-----------------------------------------------------------------------

estimates restore recco_strict_joint

scalar db = _b[c.nov_dance_recco#c.c_lag]
scalar dp = 2*ttail(e(df_r), ///
    abs(db/_se[c.nov_dance_recco#c.c_lag]))

scalar lb = _b[c.nov_loud_recco#c.c_lag]
scalar lp = 2*ttail(e(df_r), ///
    abs(lb/_se[c.nov_loud_recco#c.c_lag]))

scalar cb = _b[c.nov_complex#c.c_lag]
scalar cp = 2*ttail(e(df_r),abs(cb/_se[c.nov_complex#c.c_lag]))

scalar ob = _b[c.nov_onset#c.c_lag]
scalar op = 2*ttail(e(df_r),abs(ob/_se[c.nov_onset#c.c_lag]))

post `robpost' ("Strict Reccobeats") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)


*-----------------------------------------------------------------------
* Track fixed effects
*-----------------------------------------------------------------------

estimates restore xtFE_joint

scalar db = _b[c.nov_dance#c.c_lag]
scalar dp = 2*ttail(e(df_r),abs(db/_se[c.nov_dance#c.c_lag]))

scalar lb = _b[c.nov_loud#c.c_lag]
scalar lp = 2*ttail(e(df_r),abs(lb/_se[c.nov_loud#c.c_lag]))

scalar cb = _b[c.nov_complex#c.c_lag]
scalar cp = 2*ttail(e(df_r),abs(cb/_se[c.nov_complex#c.c_lag]))

scalar ob = _b[c.nov_onset#c.c_lag]
scalar op = 2*ttail(e(df_r),abs(ob/_se[c.nov_onset#c.c_lag]))

post `robpost' ("Track fixed effects") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)


*-----------------------------------------------------------------------
* Previous observed chart appearance lag
*-----------------------------------------------------------------------

estimates restore prevobs_joint

scalar db = _b[c.nov_dance#c.c_lag_prevobs]
scalar dp = 2*ttail(e(df_r), ///
    abs(db/_se[c.nov_dance#c.c_lag_prevobs]))

scalar lb = _b[c.nov_loud#c.c_lag_prevobs]
scalar lp = 2*ttail(e(df_r), ///
    abs(lb/_se[c.nov_loud#c.c_lag_prevobs]))

scalar cb = _b[c.nov_complex#c.c_lag_prevobs]
scalar cp = 2*ttail(e(df_r), ///
    abs(cb/_se[c.nov_complex#c.c_lag_prevobs]))

scalar ob = _b[c.nov_onset#c.c_lag_prevobs]
scalar op = 2*ttail(e(df_r), ///
    abs(ob/_se[c.nov_onset#c.c_lag_prevobs]))

post `robpost' ("Previous observed appearance") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)


*-----------------------------------------------------------------------
* Leave-one-out benchmark
*-----------------------------------------------------------------------

estimates restore loo_joint

scalar db = _b[c.nov_dance_loo#c.c_lag]
scalar dp = 2*ttail(e(df_r), ///
    abs(db/_se[c.nov_dance_loo#c.c_lag]))

scalar lb = _b[c.nov_loud_loo#c.c_lag]
scalar lp = 2*ttail(e(df_r), ///
    abs(lb/_se[c.nov_loud_loo#c.c_lag]))

scalar cb = _b[c.nov_complex_loo#c.c_lag]
scalar cp = 2*ttail(e(df_r), ///
    abs(cb/_se[c.nov_complex_loo#c.c_lag]))

scalar ob = _b[c.nov_onset_loo#c.c_lag]
scalar op = 2*ttail(e(df_r), ///
    abs(ob/_se[c.nov_onset_loo#c.c_lag]))

post `robpost' ("Leave-one-out benchmark") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)


*-----------------------------------------------------------------------
* Year + month fixed effects
*-----------------------------------------------------------------------

estimates restore yearmonth_joint

scalar db = _b[c.nov_dance#c.c_lag]
scalar dp = 2*ttail(e(df_r),abs(db/_se[c.nov_dance#c.c_lag]))

scalar lb = _b[c.nov_loud#c.c_lag]
scalar lp = 2*ttail(e(df_r),abs(lb/_se[c.nov_loud#c.c_lag]))

scalar cb = _b[c.nov_complex#c.c_lag]
scalar cp = 2*ttail(e(df_r),abs(cb/_se[c.nov_complex#c.c_lag]))

scalar ob = _b[c.nov_onset#c.c_lag]
scalar op = 2*ttail(e(df_r),abs(ob/_se[c.nov_onset#c.c_lag]))

post `robpost' ("Year + month FE") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)


*-----------------------------------------------------------------------
* Position <= 200
*-----------------------------------------------------------------------

estimates restore top200_joint

scalar db = _b[c.nov_dance#c.c_lag_200]
scalar dp = 2*ttail(e(df_r), ///
    abs(db/_se[c.nov_dance#c.c_lag_200]))

scalar lb = _b[c.nov_loud#c.c_lag_200]
scalar lp = 2*ttail(e(df_r), ///
    abs(lb/_se[c.nov_loud#c.c_lag_200]))

scalar cb = _b[c.nov_complex#c.c_lag_200]
scalar cp = 2*ttail(e(df_r), ///
    abs(cb/_se[c.nov_complex#c.c_lag_200]))

scalar ob = _b[c.nov_onset#c.c_lag_200]
scalar op = 2*ttail(e(df_r), ///
    abs(ob/_se[c.nov_onset#c.c_lag_200]))

post `robpost' ("Position <= 200") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)


*-----------------------------------------------------------------------
* Track-level source standardization
*-----------------------------------------------------------------------

estimates restore source_std_track_joint

scalar db = _b[c.nov_dance_srcstd_trk#c.c_lag]
scalar dp = 2*ttail(e(df_r), ///
    abs(db/_se[c.nov_dance_srcstd_trk#c.c_lag]))

scalar lb = _b[c.nov_loud_srcstd_trk#c.c_lag]
scalar lp = 2*ttail(e(df_r), ///
    abs(lb/_se[c.nov_loud_srcstd_trk#c.c_lag]))

scalar cb = _b[c.nov_complex#c.c_lag]
scalar cp = 2*ttail(e(df_r),abs(cb/_se[c.nov_complex#c.c_lag]))

scalar ob = _b[c.nov_onset#c.c_lag]
scalar op = 2*ttail(e(df_r),abs(ob/_se[c.nov_onset#c.c_lag]))

post `robpost' ("Track-level source standardized") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)


*-----------------------------------------------------------------------
* Within-week standardized novelty
*-----------------------------------------------------------------------

estimates restore weekly_z_joint

scalar db = _b[c.znov_dance#c.c_lag]
scalar dp = 2*ttail(e(df_r),abs(db/_se[c.znov_dance#c.c_lag]))

scalar lb = _b[c.znov_loud#c.c_lag]
scalar lp = 2*ttail(e(df_r),abs(lb/_se[c.znov_loud#c.c_lag]))

scalar cb = _b[c.znov_complex#c.c_lag]
scalar cp = 2*ttail(e(df_r),abs(cb/_se[c.znov_complex#c.c_lag]))

scalar ob = _b[c.znov_onset#c.c_lag]
scalar op = 2*ttail(e(df_r),abs(ob/_se[c.znov_onset#c.c_lag]))

post `robpost' ("Within-week standardized") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)

*-----------------------------------------------------------------------
* Minimum 4 usable exact-week-lag observations
*-----------------------------------------------------------------------

estimates restore min4_joint

scalar db = _b[c.nov_dance#c.c_lag]
scalar dp = 2*ttail(e(df_r),abs(db/_se[c.nov_dance#c.c_lag]))

scalar lb = _b[c.nov_loud#c.c_lag]
scalar lp = 2*ttail(e(df_r),abs(lb/_se[c.nov_loud#c.c_lag]))

scalar cb = _b[c.nov_complex#c.c_lag]
scalar cp = 2*ttail(e(df_r),abs(cb/_se[c.nov_complex#c.c_lag]))

scalar ob = _b[c.nov_onset#c.c_lag]
scalar op = 2*ttail(e(df_r),abs(ob/_se[c.nov_onset#c.c_lag]))

post `robpost' ("Minimum 4 usable observations") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)


*-----------------------------------------------------------------------
* Minimum 8 usable exact-week-lag observations
*-----------------------------------------------------------------------

estimates restore min8_joint

scalar db = _b[c.nov_dance#c.c_lag]
scalar dp = 2*ttail(e(df_r),abs(db/_se[c.nov_dance#c.c_lag]))

scalar lb = _b[c.nov_loud#c.c_lag]
scalar lp = 2*ttail(e(df_r),abs(lb/_se[c.nov_loud#c.c_lag]))

scalar cb = _b[c.nov_complex#c.c_lag]
scalar cp = 2*ttail(e(df_r),abs(cb/_se[c.nov_complex#c.c_lag]))

scalar ob = _b[c.nov_onset#c.c_lag]
scalar op = 2*ttail(e(df_r),abs(ob/_se[c.nov_onset#c.c_lag]))

post `robpost' ("Minimum 8 usable observations") ///
    (db) (dp) (lb) (lp) (cb) (cp) (ob) (op)

postclose `robpost'


preserve

use `robtable', clear

format *_b %9.6f
format *_p %9.4f

list, noobs clean

export delimited using ///
    "output/table_robustness_matrix.csv", ///
    replace

export excel using ///
    "output/final_tables.xlsx", ///
    sheet("Robustness") ///
    firstrow(variables) ///
    sheetreplace

restore


display "============================================================"
display "FINAL TABLES EXPORTED"
display "============================================================"



*==========================================================================
* 22. EXPORT FINAL FIGURES
*==========================================================================

display "============================================================"
display "SECTION 21 - EXPORT FINAL FIGURES"
display "============================================================"

*------------------------------------------------------------
* 22.1 Loudness marginal association
*------------------------------------------------------------

graph display g_loud

graph export ///
    "output/figure_loudness_marginal_effect.png", ///
    width(2400) replace

graph export ///
    "output/figure_loudness_marginal_effect.pdf", ///
    replace


*------------------------------------------------------------
* 22.2 Onset-rate marginal association
*------------------------------------------------------------

graph display g_onset

graph export ///
    "output/figure_onset_marginal_effect.png", ///
    width(2400) replace

graph export ///
    "output/figure_onset_marginal_effect.pdf", ///
    replace


*------------------------------------------------------------
* 22.3 Combined figure
*------------------------------------------------------------

graph combine g_loud g_onset, ///
    cols(2) ///
    xcommon ///
    name(g_combined, replace)

graph export ///
    "output/figure_state_dependence_combined.png", ///
    width(3000) replace

graph export ///
    "output/figure_state_dependence_combined.pdf", ///
    replace


display "============================================================"
display "FINAL FIGURES EXPORTED"
display "============================================================"

display "============================================================"
display "MASTER REPLICATION PIPELINE COMPLETED"
display "============================================================"
