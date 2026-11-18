# Build 51 — Product-facing UI polish

## Rule

Main navigation destinations (Today, Training, Progress, Health, Watch Home, EITAN and workout screens) should display athlete outcomes, actions, and **relevant health information**, not implementation status. The app is a fitness product, not a troubleshooting dashboard.

- Keep: actual session details, exercise progress, recent runs, goals, rest timers, EITAN score/factors, source-labelled sleep/HRV and the limitation that personal trends aren't diagnoses, IsAIah coaching and actionable health source context.
- Remove from primary cards: build numbers, background transfer errors, app-to-app reachability, queue depth, last cloud polling timestamp, cloud status, stale developer messages, and long technical explanations of synchronization.
- Preserve those details in iPhone Settings → EITAN/Connections and Apple Watch Settings → Connectivity & Diagnostics. The Watch's EITAN manual phone/cloud sync and sign-in remain reachable there.
- Empty states: short and human-readable (e.g. "No completed runs yet"), rather than implementation notes.
- Maintain accessibility labels for actual health metrics; do not suggest metrics exist when authorization/data coverage is absent.

## Review checklist

- [ ] iPhone Today: EITAN card shows wellness + useful factors/coaching only; daily IsAIah brief contains no engine explanation.
- [ ] iPhone Training: no queue status beneath active-workout tile or at top of strength; Running doesn't show watch-connection strings or transfer button beneath plan.
- [ ] iPhone Health: measurement source and clinical context visible; transport status under Settings.
- [ ] iPhone Settings: EITAN cloud opt-in and diagnostics, retry controls, account and Watch connection states remain available.
- [ ] Apple Watch Home: clear EITAN, scheduled strength/run, Health readings, and workout actions; no build or cloud route notes.
- [ ] Apple Watch EITAN detail: wellness factors and IsAIah coaching; no technical transfer block.
- [ ] Apple Watch Settings: live link, phone companion ID, build/version, cloud, EITAN transport and manual recovery controls available.
- [ ] Apple Watch strength: rest day or session info instead of sync instructions.
- [ ] Both app targets compile and run with matching Build 51.
- [ ] Workout and wellness background/cloud sync behavior unchanged.
