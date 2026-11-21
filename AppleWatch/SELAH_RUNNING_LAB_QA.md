# Selah Stone + Running Lab — implementation and validation

## Fixed visual identity
- Ash charcoal #131516, stone #1E2122, graphite #2A2D2D, weathered silver #A4A6A3, limestone #F0EEE9, sandstone accent #D8D3C7.
- Fixed native iPhone and Watch identity. No theme picker, custom shape, custom colors, font selector, or AI theme command.
- IsAIah mark uses neutral colors while preserving geometry. Scripture and motivational content remain opt-in. Reduce Motion remains an accessibility control.
- Do not delete legacy UserDefaults or styles until all historical data schema migrations are verified; they no longer affect active color tokens.

## Running Lab — actual implementation
- Historical runs: source-specific HR, power, cadence, distance, ascent; charts for authorized running speed, power, stride length, ground-contact time, vertical oscillation where recorded.
- Native Apple Health: source-matched HealthKit running dynamics for up to eight recent runs, timestamped, sampled locally; conservatively qualified GPS mile splits; original route/HR data preserved locally.
- Tredict: at most six recently recorded running activity details via approved read-only Personal API, with extraValues/allSeries/withLaps. Only actual available source series, HR, speed, power, step length, ground contact time and provider lap events are stored in iMun run summaries. Unclear vertical oscillation conversion not fabricated.
- Analytics: 7-day and 28-day mileage, prior 21-day weekly comparison when enough historical runs exist; duplicate-aware matching; best whole-run benchmark efforts, source-labeled pace comparisons, cadence and speed trends, configured-maximum-HR time in zones, descriptive HR drift conditional on closely matched speed; contextual IsAIah analysis on explicit Send.
- Shared primary wearable remains an EITAN preference while Running Lab preserves all source identities.

## Known limitations
- Garmin data comes from a connected Tredict Personal API account when available, not an authenticated Garmin Connect consumer SDK or live Garmin IMU stream.
- Time-sampled HealthKit running dynamics may be absent for treadmill, third-party exports or sources that do not publish them. They are not substituted.
- Garmin/Tredict metadata includes derived dynamics, but does not prove accurate joint kinematics, running economy, power efficiency, injury risk or VO2 max.
- Heart rate zones are rough % of a user-entered max HR; no age-derived HRmax, lactate threshold or clinical-grade inference.
- The whole-run best efforts are NOT official PRs, verified races or rolling effort records.
- A GPS split is marked as derived and not presented as an actual device lap.
- Running Lab retains recorded source data locally; only summarized statements are shared with IsAIah when the user submits a message.

## Native validation gate
1. Build HealthCoach iPhone with embedded Watch target on macOS CI; compile standalone watchOS target; run Swift portable progression and Running Lab tests.
2. On physical iPhone import an Apple Watch run. Verify HealthKit authorization, running dynamical sample permission, source-matched sample count, and correct units for Apple Watch.
3. Record an interval run. Confirm actual recorded lap events remain separate from GPS-derived complete-mile splits and that no arbitrary GPS jumps create a fast split.
4. Connect an authorized Tredict account with Garmin-derived activities. Confirm pagination, six-request cap on detail fetches, no token logged, no 429 crash, and actual non-null source metrics/lap units.
5. Verify data semantics when Tredict laps were algorithmically calculated versus recording-device lap events; label as provider laps.
6. Confirm older cached runs and cloud/Watch summaries still decode; no bulk HealthKit traces, routes or Tredict detailed records leaked into Watch/cloud packets.
7. Test overlapping Garmin/Tredict/HealthKit workouts. Ensure near-identical duplicate recordings count once, but distinct same-day runs remain separate.
8. Confirm iMun Watch's timer, structured running, lift workout, motion insights and cloud reconnect remain functional.
9. Verify both light/dark device settings still display the intentionally fixed dark Selah Stone palette and no obsolete theme pickers.
10. Confirm body metrics and IsAIah conversational health data never upload automatically.
11. Test Run Lab performance with >500 historical runs; chart sampling, route extraction and scrolling should remain smooth.

## Later milestones, not claimed as implemented
- True rolling GPS best efforts (400m/1K/1mi/5K), personal records with segment confidence and GPS quality indicators.
- Training-load model with scheduled versus completed interval compliance; running threshold/FTPace/critical-speed estimation with uncertainty.
- Terrain/grade-adjusted pace, hill repeats, heat/humidity adjustment using verified environmental records.
- Detailed auto-segmentation, interval detection, pace zones, power zones, recovery HR, cadence/stride distributions, biomechanics trend normalization by speed and grade.
- Direct Garmin authorized API where accessible, FIT/TCX/GPX import, optional footpod/Stryd support, and source selection per metric.
- Longitudinal aerobic/anaerobic trend, 5K–marathon forecasts and injury-prevention education with evidence/confidence (not diagnosis).
- Shoe mileage tracking, workout gear, route planning, goals, race calendar, training blocks, triathlon bricks, fueling and hydration journal.
- Dedicated native watch Running Lab charts and in-run cue customization; cloud-based cross-device trend calculations with user consent.
- Social, challenges and sharing only if the user wants these; privacy-first baseline does not depend on social accounts.
