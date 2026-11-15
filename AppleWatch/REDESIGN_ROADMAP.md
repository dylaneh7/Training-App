# imun — Native App Redesign Roadmap

This document records the agreed direction for the existing native iPhone + Apple Watch application. The iPhone and its Command Center planner remain the authoritative schedule; the Apple Watch is a companion, not a separate scheduler. The app must keep existing source-attributed HealthKit / Tredict / Garmin history and offline workout logging.

## Release 1 — Navigation and visual foundation (implemented in branch `imun/phase1-training-navigation`)

- Four bottom destinations: **Training**, **Progress**, **Recovery**, **Coach**.
- A top-level Training sport selector that starts with **Run** and **Weightlifting**. The date-matched planned session title appears directly underneath. The chosen sport is remembered.
- Exercise logging, strength session editor, training history, run health import, upcoming calendar and moving scheduled sessions remain functional.
- Coach gets its own home/briefing with the actual working-set completion ring and a single Settings button/top-right gear.
- Existing preferences, accent palette, Watch controls, account connections, coaching notes and export remain under **Coach → Settings**.
- Shared SwiftUI progress-ring and insight-chip visual components support consistent dark-card layouts. Rings are tied to actual recorded measurements only; no fictional recovery score.
- No changes to WatchConnectivity schedule or HealthKit workout engine in this release.

## Release 2 — Recovery intelligence (planned, not yet implemented)

- Replace raw-number-only presentation with clean rings, sparklines, reference bands, trend chips, and clear missing-data states.
- Display individual source-attributed metrics (sleep duration/consistency, resting or daily-low HR, HRV, respiratory rate when available, strain, subjective soreness and energy). Do not mix SDNN, RMSSD, and WHOOP proprietary scores as though they share the same units.
- Comparisons to prior day, rolling 7-day and 28-day personal baselines, with minimum-observation thresholds and units visible.
- Detect values outside a meaningful personal range; mark the direction and magnitude and explain uncertainty. Alerts are informative and non-diagnostic, and notifications are opt-in and configurable.
- Only show any aggregate recovery/readiness indicator if its derivation and input quality can be explained; no made-up score or false precision.

## Release 3 — Contextual Coach and secure AI (planned)

- Daily briefing from real planned sessions, completed runs/strength sets, recovery trends and check-ins.
- Actionable but conservative coaching suggestions, post-session explanations, weekly summaries, and optional training-plan adjustments for user confirmation.
- An **Ask Coach** conversational screen. Use a secure server-side AI integration (for example via an authenticated Supabase Edge Function), never put a provider API key in the iPhone or Watch app. Minimize personal data, require opt-in for health-data sharing, and make it clear when answers are AI generated.
- Keep deterministic rules and data provenance visible, distinguish training advice from medical interpretation, and avoid changing a calendar without user approval.

## Release 4 — Running engine and audible coaching (planned)

- A dedicated in-workout UI for live pace, heart rate and HR zone, distance, interval stage, elapsed time, current lap and target.
- Interval definitions for warmup, work, recovery, repeats and cooldown; correct advancement by time or distance.
- Spoken headphone cues and optional haptics at interval transitions, plus configurable cadence-based or distance-based heart-rate/pace/time updates.
- Automatic mile or kilometer laps, split pace, lap summaries and configurable units; manual laps remain available.
- Correct foreground/background exercise-session and audio-session handling on physical iPhone/Apple Watch. Avoid claiming real-time connectivity when unavailable.
- Post-run distance, splits, pace, HR, workout segments, source attribution, route if granted, and comparison with comparable recent runs.

## Release 5 — Watch refinement and synchronization (planned)

- Wrist-first navigation matching Training, recovery summary and workout focus while using readable metrics and compact rings.
- Watch continues to request a date-stamped schedule from the iPhone, supports offline sets and session events, and reconciles them when devices reconnect.
- Audible interval announcements should route through the device/headphones that are actually recording the run; avoid duplicate spoken cues from phone and watch.
- Watch haptics, reliable permissions, pause/resume, workout finish and data synchronization require testing on physical devices.

## Release 6 — More training disciplines (planned)

- Add cycling, stretching/mobility and other types inside the **Training** selector, not as more bottom navigation tabs.
- Give each sport its own plan schema, activity-specific live metrics, completion events and history while sharing the same date-scoped daily schedule.
- Avoid falsely presenting generic tracking as a fully implemented sport before its workout engine exists.

## Validation and shipping

- Keep the existing Xcode project and GitHub remote; use a feature branch + CI checks and then merge to `main`.
- Check both iPhone and Watch targets in CI. Simulator compilation is not a substitute for real-device HealthKit, audio, location or background-delivery testing.
- Free Apple Developer account means native updates still require **Integrate → Pull** and **Run** from Xcode. Workout schedule/configuration updates may arrive via existing cloud sync without new app binaries.
- Never replace working signing settings, overwrite the user's local project changes, add client-side API secrets, or delete historical training data to ship a UI redesign.
