# iMun Build 40 — Progress, Health and navigation polish

## User-requested visual changes
- Progress: strength progression and running charts appear **directly after the hero**, not after the upcoming workout list.
- Upcoming workouts: only three appear by default; the See all/Show less control reveals or collapses the rest of the existing upcoming schedule (currently capped to 45 records in the page).
- Health: four small source-specific at-a-glance readings—sleep, HRV, resting heart rate and steps—with actual date/provider attribution or em dashes for missing data; no synthetic combined score.
- Health: category and source search remain pinned at the top while the large Health hero scrolls away. The All category groups metrics into collapsible sections; existing individual source rows and trend charts remain intact.
- Training / Progress / Health / Settings: compact native navigation titles paired with in-content titles that scroll away. Training only shows its compact native title after its own header collapses.
- Shared quiet skeleton placeholders for the first progress or Health data load and restrained numeric/opacity transitions; no ongoing shimmer work while the user scrolls.
- Settings: lazy section rendering, consistent with Progress and Health.

## Preservation
- No changes to logging, workout edits, Garmin/Tredict/WHOOP data, HealthKit permission scopes, Watch syncing, Coach tool calls, Coach branding, app design presets or database schema.
- HealthKit readings are still attributed by provider and HRV calculation method.
- IsAIah still gets only authorized Health readings when sharing is enabled and a message is sent.
- Theme styling continues through HCDesign / IMUNStyle; Progress heading remains serif for Heritage/Atelier.

## Device / build validation
- [ ] iOS Xcode build succeeds
- [ ] watchOS Xcode build succeeds and Watch install still pairs
- [ ] Progress on first open scrolls smoothly and charts are immediately above the schedule
- [ ] Progress See all/Show less and Move day operate without changing training data unexpectedly
- [ ] Health sticky filters don't jump or overlap iOS status/navigation bars
- [ ] Health four at-a-glance values show the correct individual source, date and method
- [ ] All categories expand/collapse; metric search and selected filters work together
- [ ] WHOOP/Apple Watch Sleep and HRV remain one detailed card per metric, source rows separate
- [ ] Missing Apple Health permissions show placeholders and access guidance, not fictitious numbers
- [ ] Training/Progress/Health/Settings titles and scrolling feel consistent in all existing themes
- [ ] No unnecessary full HealthKit reload on tab changes; manual Refresh still works
- [ ] IsAIah chat and Health context still work; no watch or cloud regression

GitHub CI may remain queued until a macOS runner starts. The actual scrolling performance and native build must be tested on iPhone.
