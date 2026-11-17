# iMun Build 31 — Coach controls, Training, Health, themes and motivation

## Included in Build 31

### Coach controls with explicit approval
Coach's conversational view now recognizes and previews:
- Move a real, dated calendar workout
- Mark today's prescribed run complete (user assertion, not an Apple Health recording)
- Mark any saved calendar strength/run workout complete via an authenticated server function
- Create a custom strength workout (empty exercise list until the athlete adds movements)
- Create a timed running workout on an empty day (optional user-supplied BPM limits)
- Rename today's strength workout while preserving its exercises
- Refresh the existing iMun Watch workout sync
- Change visual themes, motivation source, rest-timer override, Watch haptics, running voice cues and auto-lap settings
- Switch between Strength and Running and navigate Training, Progress, Health, Coach or Settings

Every mutation requires a review card and Confirm Action. An ordinary AI reply is never executable code. App state and user-owned workout IDs are validated again when confirming. Common commands are recognized locally. When wording is more conversational, the signed-in Coach AI can return a strictly validated JSON **suggestion** from the same allowlist. A model response never contains executable instructions and still requires explicit user approval. If the model cannot classify an action, the ordinary Coach answer is shown. This is not unrestricted AI tool execution or unsupervised full-app automation.

### Create today's run and export it to Apple Workout
- Training → Running offers **Create Today's Run** when there is no running plan.
- Name, prescribed duration (1–360 minutes), optional low/high HR targets are editable.
- The local run persists through calendar refreshes and is published as part of the existing dated iMun Watch schedule.
- When opening Apple's structured WorkoutKit editor, typed steps from iMun are preserved instead of becoming "Open" / "Free Run."
- A created prescription never counts as a completed workout until a recorded or explicitly user-confirmed completion arrives.

### Health tab
- Apple Watch and WHOOP sleep remain **in one source-attributed Sleep card**. No averaging or duplicated Sleep metric cards.
- The Health tab now caches expensive per-source signals, baseline and trend calculations and refreshes that cache on underlying Apple Health/recovery updates; measurements, values and source labels are unchanged.
- Recovery score and diagnostic judgments are not invented.

### Themes & motivation
- Shared section headings have theme-specific typography, symbols, and rules for Heritage, Retro, Techno, Coast, Field Notes, Discipline, Atelier and Rally.
- The racing flag remains exclusive to Rally.
- Motivation's source, translation preference and tone are separate from appearance.
- **Quiet, Direct and Rigorous** actually select different original/performance message sets; Scripture uses ESV/LSB references without embedding licensed translation text.
- Existing saved messages, notes and personal journal are preserved.

### Existing roadmap steps already implemented
- Collapsing Training header on scroll, without a redundant global Training refresh button
- Single Settings tab (the Coach tab is a conversation, not a second Settings screen)
- Watch-guided strength sets with rest countdown, manual or automatic advance, exercise selection and offline saving
- Native Apple Workout interval export with time/distance and BPM alerts, plus independently published workout schedule in Build 30
- Watch and phone synchronization remains unchanged from the working Build 30 release, including original app bundle IDs

## Explicitly excluded
- WHOOP band direct BLE/hardware integration and expired-membership protocol reverse engineering, deferred at the user's request
- Unrestricted AI control of all functions, unsafe arbitrary database edits, fabricated workout metrics or unsupervised permanent actions

## Backend
The private Supabase project has the new `imun_mark_planned_workout_complete` RPC deployed. It is SECURITY INVOKER, uses the signed-in user's RLS-protected planner row, changes only the chosen workout's completed flag and a manual-completion tag, and has EXECUTE granted to `authenticated`, not `anon`. Source SQL: `AppleWatch/Backend/imun_mark_planned_workout_complete.sql`. Unknown workout IDs are rejected; a rolled-back transaction and privilege checks have been performed.

## Release validation
- Build 31 includes both iOS and watchOS target version increments but does **not** change their mandatory companion pairing or existing cloud transport.
- GitHub Actions macOS Xcode CI validates source compilation before merging.
- Actual physical-device testing remains necessary, especially the automatic Apple Workout schedule, watch connectivity, Health performance and final Coach confirmation flows.
- Do not delete either app during upgrades because unsent set logs and local journal records may be lost.
