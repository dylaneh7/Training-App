# imun v2 — One-pull redesign release

This release is one native source update for the existing iPhone and Apple Watch apps. It keeps the same Xcode project and existing Command Center/Supabase calendar, history and WatchConnectivity protocol.

## Implemented

- **Visual identity:** richer graphite/navy surfaces, atmospheric hero cards, real progress halos, insight chips, clearer type and spacing.
- **Navigation:** four bottom destinations (Training / Progress / Recovery / Coach), with Run and Weightlifting inside Training; future sports fit inside the activity selector rather than requiring more bottom tabs.
- **Training:** current-day planned workout, original lift editor and set logging, real recorded-set completion ring, actual run target distance ring and comparable previous-run pace insight.
- **Progress:** redesigned dashboard with recorded sessions and the existing history graphs/calendar.
- **Recovery:** source-attributed HRV, sleep and HR baseline cards, normalized visual rings (not medical scores), charts and highlighted unusual personal changes. Baselines compare a minimum five earlier comparable daily readings within seven days, or within 28 days; when a source supplies an HRV baseline it may be used instead. Different HRV definitions are not combined. Latest Apple Health quantities can use source-specific daily medians from the last 35 days; missing data is indicated.
- **Coach:** redesigned daily briefing from actual schedule, Ask Coach interface with an authenticated Supabase Edge Function, optional additional consent for sending recovery summaries. There is no embedded provider secret in the app, and no automatic AI calendar modifications.
- **Settings:** all prior controls remain under Coach → Settings. New running controls include optional spoken cues, automatic mile splits, timed-interval preset and one/two/five/ten-minute HR/pace announcements.
- **Watch:** refreshed home dashboard and recent recovery glance, run pacing display, mile-progress indicator, automatic mile lap recording, 5-min warmup / 5 × (3-min effort + 2-min easy) / cooldown interval phase changes with haptics/spoken cues when enabled.
- **Backend:** new authenticated `imun-ai-coach` Edge Function, versioned in `supabase/functions/imun-ai-coach/index.ts` and deployed to the existing project. Requires the project-level `OPENAI_API_KEY` secret and an enabled compatible `OPENAI_MODEL` to answer; otherwise the interface displays an unavailable error. Requests have an input cap and a best-effort per-instance rate limit. Recovery data is only included with opt-in.

## Scope and caveats

- **User data:** No historical workout, training or recovery records are removed or migrated by this release.
- **Audio:** Announcements come from the Watch while a run is tracked. Whether they reach paired headphones or the Watch speaker depends on watchOS audio routing. Physical-device validation is required for wrist-down/background delivery, Bluetooth audio, HealthKit distance/HR and reliable interval timing.
- **Comparisons:** Recovery changes are descriptive training observations, not diagnosis, and thresholds are heuristic, not medical normal ranges. A filled ring indicates a normalized amount of the measured signal; it is not a fabricated readiness score.
- **AI:** The response is generated from the explicitly submitted question and limited training summaries. No model API key should ever be added to the Swift code. The backend does not write its conversations to a database, but the model provider's retention/processing terms still apply.
- **Scheduled sports:** Cycling, stretching and additional sports are architectural extension points, **not** fully functional trackers in v2. Do not promise workout tracking for them until the data models and HealthKit engines are implemented.
- **Free developer account:** There is no free TestFlight or automatic over-the-air binary distribution. On the user's Mac, one `Integrate → Pull` from `origin/main`, then Run on the physical iPhone and Watch installs this single batch of native code changes.
- **Testing:** GitHub CI compiles both targets in the simulator. Check sign-in, calendar-rest day, workout edits, sync, Health permissions, actual run/lap/speech and AI chat on personal devices after installation.

## Acceptance checklist

1. Pull once on the cloned GitHub/Xcode project; verify both targets sign with the user's Personal Team.
2. Run HealthCoach iPhone, then HealthCoachWatch on physical watch.
3. Training: switch Run / Weightlifting, verify the correct date-scoped plan and session controls.
4. Coach → Settings: saved accents, account, Watch preferences; set voice/laps/cadence and open the Watch Run screen to confirm settings.
5. Recovery: connect Health and Tredict. Verify source, units, date, comparison window, meaningful missing-data states and unexpected-value banners.
6. Watch: do a short outdoor run with location and HealthKit permission, confirm distance and HR; test voice output and intervals with headphones. Auto-laps require actual measured distance; do not fake mile splits when data is unavailable.
7. Ask Coach: ask a low-stakes training question. If backend reports unavailable, inspect Supabase function configuration and available project key (not the Swift client).
