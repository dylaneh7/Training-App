# iMun Build 35 — IsAIah anywhere / Watch at a glance

## Brand decision (final)
- Keep a fixed, original IsAIah identity, related to the IMUN "im" app mark:
  graphite background, cream lettering, singular crimson geometric accent.
- Chosen direction: precision-frame "IA" (former concept C), red rather than blue.
- The logo is a SwiftUI vector in `Shared/IMUNDesignSystem.swift`, not an
  externally loaded asset; it scales without raster blur on iPhone and Watch.
- Branding is **constant** across iMun themes. Launcher border and surrounding
  Coach UI draw from `IMUNStyle.palette` / `HCDesign` and change with the
  user's preset.

## iPhone
- Native tabs: Training, Progress, Health, Settings. No Coach tab.
- The floating IsAIah button appears over each main tab, above the tab bar,
  using the same IA mark and the selected theme's accent trim.
- Tap to open an IsAIah sheet with retained conversations, action confirmation,
  app controls, and keyboard composer.
- The sheet captures the active tab, selected training activity, today's visible
  plan, and (for Health) selected category and last tapped metric trend.
- Context is sent **only when the athlete taps Send**. Recovery numbers still
  require the independent opt-in. No screen recording or arbitrary UI access.
- A legacy `hcSelectedTab=coach` is redirected to Training; Coach navigation
  commands still open the assistant.

## Apple Watch
- Watch home prioritizes daily IsAIah brief, Strength/Run, today's plan, and
  three real recovery readings (sleep, HRV, daily low HR) with source and date.
- No synthesized blended recovery score. Missing values are shown as dashes.
- The daily brief uses local synced plan and source-labelled readings; it is
  an **on-device summary**, not a newly generated server AI response.
- Watch Settings contains iPhone connection status and live link test, cloud
  connection test, plan refresh, last sync, and detailed status messages.
- Existing secure cloud backup and automatic syncing remain intact.

## Required release checks
- [ ] iOS scheme `HealthCoach` builds with no Swift errors.
- [ ] watchOS scheme `HealthCoachWatch` builds with no Swift errors.
- [ ] No Watch companion embedding/regression from Build 30.
- [ ] Four visible iPhone tabs and one functional persistent IsAIah launcher.
- [ ] Launcher uses same permanent mark in Techno, Heritage, Coast, Retro and
      other presets; outline and Coach UI update with active theme.
- [ ] Screen awareness reflects Training Run/Strength, Health selected
      category/metric, Progress, and Settings without health data leakage.
- [ ] Local chat history and reviewed Coach actions still work after tab removal.
- [ ] Watch home has no connection test buttons; tests are in Settings.
- [ ] Watch shows sleep, HRV, low HR from the actual source and date, or a
      graceful empty state.
- [ ] Daily brief matches the actual synced workout/run or rest day.
- [ ] iPhone + Watch install over the existing apps, retain data and sync.

Final two checks require physical iPhone/Apple Watch testing. Never claim
release-ready until iOS and watchOS CI is green.
