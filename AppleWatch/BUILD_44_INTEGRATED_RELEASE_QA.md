# iMun Build 44 — One-pull release / QA contract

Four development phases are bundled into ONE native update. **Do not pull/run until
both iPhone and watchOS CI checks are successful and the branch is merged to main.**

## Phase 41 — Today and workout continuity
- New Today tab contains the actual date-matched strength/run plan, prescribed
  vs logged sets, recent source-labeled Health readings, and a local IsAIah
  briefing that never claims to be a remotely generated AI response.
- Start or resume the existing iPhone strength session in one tap; opening a
  planned run routes to existing Training controls (doesn't fabricate a run).
- Persistent active-workout mini-bar spans app tabs and exposes a real
  elapsed-session clock, rest-end countdown and pending cloud uploads.
- Watch now forwards a dated start/finish/undo clock status to the iPhone.
  The persistent mini-bar recognizes Watch-origin sessions, labels their source,
  and offers Continue from Watch without silently fabricating a second start.
  Queued and live status messages are ordered by their reported timestamp.
- Cloud progress polling is de-emphasized while browsing Health/Progress;
  an active Watch/iPhone workout remains eligible for reconciliation.
  Existing set records, offline corrections, and undo remain intact.

## Phase 42 — Progress and Health detail
- Progress has 7/30/90-day filters, actual logged lifting volume, running
  distance, active days, a conservative consecutive-day streak, and exercise
  personal load records; exercise detail shows real set history and chart.
- Health source preference (Auto, WHOOP, Apple Watch and other observed
  sources) controls its highlights without combining incompatible source/method
  readings. Tappable metric details have 7/30/90-day charts and existing
  same-source baselines; no invented readiness score or diagnosis.

## Phase 43 — IsAIah contextual analysis and app actions
- Context includes measured previous/recent 30-day running pace and genuine
  historical performance sets/records. No derived numbers without recorded
  elapsed time and distance.
- Opt-in Health snapshot is prioritized within the request context limit;
  context is uploaded only on explicit Send.
- Existing validated action catalog, review-before-apply, undo set/workout,
  local conversation persistence, and theme-aware UI are preserved.

## Phase 44 — VYRMUN identity for Watch Home
- Watch opening tile is full-width rather than cramped beside a sets graphic.
- **VYRMUN** (veer-moon) is an original iMun brand name, not a historical Hebrew word:
  inspired by `imun` (training) and `emunah` (faithfulness / steadfastness).
- Watch subtitle: **Steadiness in motion**. The detail screen explains the name,
  measured components, reference targets, and what happens when data is missing.
- Score is a descriptive activity-momentum indicator, not a medical readiness
  prediction; it never counts missing Health readings as zero.
- [ ] Watch Home VYRMUN typography fits smallest supported display
- [ ] Score details explain each component and source; no bogus ready/not-ready claim

## Phase 44 — Widgets and premium iOS integration
- Embedded WidgetKit app extension includes small/medium Today Home Screen
  widgets, Today rectangular Lock Screen glance and a direct workout shortcut
  (circular/rectangular Lock Screen).
- Workout Live Activity shows actual title, sets, and native rest countdown
  on Lock Screen / Dynamic Island while strength session is active.
- Widgets use app-group snapshots. Health widget data is OFF by default and
  removed from shared storage on opt-out; Live Activities have their own
  Settings toggle. Stale previous-day plans show a refresh message.
- App URL routes `imun://today` and `imun://training` open the right tab.
- Both iOS/Watch and widget targets declare Build 44. Widget is embedded
  into the main iOS app; no manual code copying or project regeneration.

## Build and device acceptance
- [ ] Xcode project parses and CI `HealthCoach` iOS simulator build is green
- [ ] Xcode `HealthCoachWatch` watchOS simulator build is green
- [ ] WidgetKit extension is correctly embedded and signed on the user's team
- [ ] App Group `group.com.dylaneh7.HealthCoachNative` exists on the team's
      provisioning profile; Xcode may request enabling it for the app/widget
- [ ] One iPhone app update preserves locally recorded sets and data
- [ ] Today opens with actual plan/recovery or honest empty states
- [ ] Start/resume workout, rest countdown, finish and undo still work
- [ ] Watch completed sets merge without double-counting or deleting unsynced sets
- [ ] Start strength on Watch while iPhone is on Today: status bar shows Watch session
- [ ] Continue from Watch in iPhone Training adopts same start timestamp; no duplicate clock
- [ ] Finish/undo on Watch removes stale iPhone banner after live/queued status receipt
- [ ] Reconnecting Watch replays current status; stale yesterday's session never appears active
- [ ] Progress charts, exercise personal records and 7/30/90 filters agree
- [ ] Health preferred source switch never labels WHOOP as Apple Watch
- [ ] IsAIah explains month-over-month running pace from actual records
- [ ] IsAIah requests permission/review before editing any record
- [ ] iPhone widget updates when iMun is used, day rollover never claims stale
- [ ] Health widget OFF by default; ON explicitly exposes only labeled values
- [ ] Lock Screen shortcut opens existing Training tab
- [ ] Live Activity ends after workout completion/undo
- [ ] Existing themes, the IsAIah launcher and Watch companion still work

The CI pipeline cannot prove the physical-device performance, widget gallery
visibility, Apple Team provisioning, Live Activity permission, or paired-Watch
behavior; those require the user's ONE post-merge installation/verification.
