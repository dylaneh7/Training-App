# Selah Stone + Running Lab — implementation and validation

## Fixed visual identity
- Ash charcoal #131516, stone #1E2122, graphite #2A2D2D, weathered silver #A4A6A3, limestone #F0EEE9, sandstone accent #D8D3C7.
- Fixed native iPhone and Watch identity. No theme picker, custom shape, custom colors, font selector, or AI theme command.
- IsAIah mark uses neutral colors while preserving geometry. Scripture and motivational content remain opt-in. Reduce Motion remains an accessibility control.
- Do not delete legacy UserDefaults or styles until all historical data schema migrations are verified; they no longer affect active color tokens.

## Running Lab — implementation in this draft branch

- **Recorded data:** Source-attributed Apple Health / Apple Watch heart rate, distance, cadence, speed, power, stride length, ground contact time and vertical oscillation. Optional HealthKit post-run same-publisher HR readings are used only when actually available.
- **Tredict / Garmin:** A bounded read-only Personal API import fetches up to six recent run details with `allSeries=1`, `extraValues=1`, `withLaps=1`. Preserves source-sampled position, HR, cadence, speed, grade-adjusted speed, power, altitude, grade and provider dynamics. Unclear units are labeled as provider units; no invented conversion or direct Garmin SDK claims. No account credentials exported.
- **Advanced pacing:** Rolling 400m / 1K / mile / 5K / 10K GPS-derived efforts when route quality and coverage allow; candidate faster intervals, measured lap events versus inferred GPS splits, first/last complete mile analysis.
- **Physiology:** Optional user-entered max HR, critical power, and threshold pace; time-limited sample HR/power/pace zones; same-publisher post-run HR recovery when recorded; descriptive speed-matched cadence/stride/contact comparisons and speed-to-HR observations.
- **Outdoor:** Sampled GPS quality and covered distance, measured ascent/descent, provider grade-adjusted speed when available, manual temperature and weather notes for qualified observed comparisons. No calibrated environmental heat-pace correction is claimed.
- **Progress and projections:** De-duplicated unique running volume and rolling trends; best whole recorded efforts; bounded race model with uncertainty and explicitly nonautomatic four-week volume/taper previews. A four-week sample does not constitute a race training prescription.
- **Athlete journal and planning:** Local mileage/frequency goals, shoes with manually assigned miles, races, effort, fueling, hydration and run notes. Planned versus recorded session **dates** only, not full interval compliance.
- **Cross-source preservation:** `PhoneWorkoutBridge` retains Apple/Garmin/Tredict source recordings separately; Running Lab de-duplicates mileage and favors a richer intact recording when two publishers appear to describe the same run. Deep Analysis exposes the matched source summaries without claiming either is more accurate.
- **IsAIah:** Explicit user-triggered analysis receives a compact evidence summary, goals and upcoming event. Raw GPS/sensor traces and user journal text are never automatically included. Native motion summaries are also available via the earlier Wearable Intelligence change.
- **Selah Stone:** Permanently fixed ash/limestone/stone colors and typography, with theme customization removed; Scripture and motivation remain opt-in.

## Known limitations
- Only the source data actually published to Apple Health or Tredict is available. Consumer Garmin Connect direct SDK authentication and live Garmin accelerometer/gyroscope streaming are **not** implemented.
- Rolling GPS estimates require timed, plausible route segments and do not constitute official certified PRs or exact speed/gait measurements. Race projections are illustrative models rather than predicted results with calibrated confidence intervals.
- HR and power/pace zones are user-threshold percentages, not measured ventilatory thresholds, lab running economy, calibrated injury risk, personal diagnosis, or verified effort recognition.
- Garmin/Tredict `seriesSampled` values may reflect external sensors such as Stryd versus watch hardware; provider series with unknown units remain source-labeled rather than converted or merged.
- Automatic weather forecasts, temperature/humidity compensation, custom map route authoring, in-run Watch-only live Running Lab, native FIT/TCX file parsing, and autonomous calendar/plan changes are **not implemented**.
- Local running logbook and shoes are not yet account/cloud synced. Event goals do not change Tredict plans or Apple workouts.
- The Xcode native iPhone and Watch build and actual sensor validation are release gates.

## Validation checklist
1. Build iPhone with Watch embedding and standalone watchOS target on macOS, run shared Swift tests and portable Running Lab smoke suite.
2. On physical iPhone, grant running HealthKit permissions and test outdoor/indoor Apple Watch run imports, including actual missing fields. Verify source matching and unit conversion.
3. Verify same-publisher post-run HR samples at approximately 1 and 2 minutes, and missing-sample handling. Cooldown activity must not be diagnosed as poor recovery.
4. Test GPS sample gaps, stationary jitter, tunnel, unrealistic speed spikes, short/long route downsampling and distances shorter than each best-effort target.
5. Compare Apple Health lap events, Tredict `withLaps` laps and GPS-derived mile splits. They must be separately attributed.
6. Connect personal authorized Tredict account with Garmin run details. Confirm current API schema, read-only cap, rate limit/401 handling, original time series and provider-specific units.
7. Import the same real-world run through Apple Health, Garmin/Tredict and iMun Watch. Verify all per-source records remain selectable and measured mileage is counted once; distinct same-day runs must remain independent.
8. Run with no data, hundreds of historical runs and slow network. Verify charts and scrolling remain responsive and no stale HealthKit query overwrites fresher details.
9. Verify old serialized runs and gearless histories decode, and that source raw traces/GPS/route splits are never sent in iPhone–Watch sync payloads.
10. Test weekly goal edits, shoe retire/restore, assignment, journal save/reload, race entries and four-week preview against local-only persistence and accessibility.
11. Validate IsAIah receives only text after a user sends a message; no raw route/GPS or manual journal text is silently transmitted.
12. Regression-test all previous Strength, EITAN, Watch motion, structured running, cloud connection and Watch workout flows.

## Subsequent work — NOT claimed as built
- Route planner/editor with maps and GPX import/export; turn-by-turn live guidance; automatic race route elevation.
- External automatic weather and humidity service with correct historical weather and data-quality indicators; validated grade-adjusted pace model.
- Live native Garmin SDK where authorized, direct multisensor cadence/stride fusion, footpod and treadmill calibration.
- Automated training block authoring/editing with explicit user approval, robust planned-versus-completed structured interval scoring, workout compliance and interval type classification.
- Validated VO2max/critical-speed/lactate-threshold modeling from multi-session tests, athlete-specific exercise economy and evidence-backed biomechanical education.
- Dedicated watchOS Running Lab pages, running alerts, shoe/cloud sharing, multi-sport swim/bike/brick training, race fueling calculations, friends/challenges and opt-in sharing.
