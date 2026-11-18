# Build 57 — Apple Health connection and evidence-led IsAIah coaching

## Changes
- A named Apple Health access card is visible near the top of Health and Settings; the duplicate hidden workout importer card is retired.
- One HealthKit read authorization request includes metrics, workout records, sleep and workout routes; importing starts after the permission request completes.
- Import status reports **actual workouts, runs and WHOOP-source records**; HealthKit does not reveal read-authorization status to the app.
- VO2 max gets a sparse 365-day sample window; dense metrics retain 35-day bounds for performance.
- IsAIah can receive early and recent VO2 max training readings with source attribution only after explicit Health sharing and Send.
- Coaching guidance emphasizes actual date/source comparisons, limits of correlation, sustainable decisions, approval before plan edits and one relevant follow-up.
- IsAIah's conversational recommendations include sensible starter questions, suggested next questions and an on-device run-pace evidence graph for recorded, non-missing paces (when >=3 runs).

## QA checklist — physical iPhone after native build
- [ ] From Settings, see Apple Health card without scrolling through Diagnostics.
- [ ] From Health, see the same compact Apple Health connection card before the metric tiles.
- [ ] Tap Connect Apple Health; HealthKit permission flow opens (unless iOS remembers a prior decision); no crash.
- [ ] Health importer includes workouts of all activity types and actual WHOOP-source records that HealthKit permits.
- [ ] Connect/read should not say all permissions were granted when no records are returned.
- [ ] The "Sync Health data" action refreshes available Health metrics and workouts.
- [ ] Data-source Health section does not show a second competing Connect button.
- [ ] IsAIah asks appropriate follow-up questions when reporting heavy legs or recent stalled progress, distinguishing possible fatigue from diagnosis.
- [ ] Running review cites measured dates/sources and provides run pace chart only when at least three meaningful samples exist.
- [ ] With IsAIah Health sharing **off**, outbound chat context does not contain Apple Health-only workout summaries or VO2 max.
- [ ] With IsAIah Health sharing **on**, relevant Apple Health training observations and sources are included only on Send.
- [ ] If several recent VO2-max samples exist, older samples from a longer observation period are available to the conversation.
- [ ] Existing HealthCoach app launches on iPhone; PhoneWorkoutBridge and Watch remain functioning.
- [ ] Compilation of both iPhone and watchOS targets passes in Xcode; force quit and re-open preserve connection status and existing data.

## Source and privacy considerations
Apple Health data on a phone may differ from a separate connected ChatGPT Health account. Neither iMun nor IsAIah can infer unavailable HealthKit read permissions; show what was actually imported. Recorded run pace values can vary by route, terrain, HR sensors and effort. IsAIah's suggestions remain advisory, and workout changes require user confirmation.
