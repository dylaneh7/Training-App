# iMun product roadmap — design, motivation, and reliable training

This plan preserves the owner's requested direction while implementation proceeds in tested stages. The iPhone and Apple Watch apps are one product, not separate designs.

## Phase 1 — FIRST PRIORITY: iPhone ↔ Watch reliability
- Show **today's actual scheduled workout**, all prescribed exercises, loads, reps, and set counts on Watch.
- Distinguish "queued", "delivered", "decoded", "loaded", "rest day", and "not signed in" in status messages. Never label an outgoing transfer as loaded without Watch confirmation.
- Validate a date-scoped workout ID in acknowledgments; don't apply yesterday's plan to today.
- Preserve offline workout sets, workouts in progress, and unsent events. No automatic deletion of apps or workout data.
- Test with real paired devices, including Watch unreachable/reachable, iPhone background/foreground, calendar refresh, midnight, edits, and duplicate delivery.
- If the phone reports the Watch app is not installed, distinguish `isPaired`, `isWatchAppInstalled`, and `isReachable` in a user-visible connection diagnostic. Inspect companion association, embed path and physical installation before changing workout logic.
- Show iPhone and Watch installed build numbers; use incrementing build numbers for device tests.

## Phase 2 — Timers and set-by-set Watch workout
- Clear start workout → active exercise → start set → save set → rest → next set → finish path, with one prominent action at a time.
- Easy controls for reps, load, RIR, set override, exercises out of order, manual skip rest, paused workouts, and haptic rest completion.
- Accurate timers through wrist-down/app suspension using persisted timestamps, with no duplicate set logging or silent automatic completion.
- Make auto-start of a new working set after rest configurable (manual start by default should be considered during user testing).
- Mirror completed sets back to the iPhone and cloud; preserve IDs for deduplication.
- User can create a workout or run on unscheduled days.

## Phase 3 — Redesign and personal iMun identity
- Cohesive iPhone and Watch typography, iconography, navigation, page layout, typography scale, widgets, and training hierarchy.
- User-selectable appearance presets, with themes independent from content preferences:
  1. **Heritage** — vintage collegiate/sporting club, cream, deep forest green, oxblood, classic serif details.
  2. **Retro** — warm analog timers, athletic scoreboards, film/print texture.
  3. **Techno** — precise telemetry, restrained neon, dark panels, progress charts.
  4. **Coast** — sun-faded blue, sand, sea-glass, open light spaces.
  5. **Field Notes** — outdoors, trail map contours, moss, stone, weathered paper.
  6. **Discipline** — minimalist monochrome, military precision, high-contrast utilitarian focus.
  7. **Atelier** — premium editorial design: asymmetrical layouts, oversized restrained headings, thin keylines, elegant type hierarchy, and inset photographic panels.
  8. **Rally** — motorsport/competitive-athlete: chamfered/angular cards, split-time scoreboards, segmented progress, racing-number treatments, and decisive action buttons.
- Presets change the **entire design system**, not just accent colors: card silhouettes and corner geometry, navigation bar and tab treatment, button form, typography, background texture/motifs, spacing density, progress rings, graphs, and motion. Apply coherently to EVERY major iPhone page (Training, Progress, Health, Coach, Settings, Motivation) and the Watch versions.
- **Custom Design Studio**: select accent/background/surface/text colors; light/dark/system; card shape (rounded, squared, chamfered, pill, asymmetric); corners, borders, button shape, heading/body font presets, spacing density, navigation style, progress indicator style, optional background motifs, and haptic/animation intensity.
- Provide live previews for iPhone and Watch. Validate contrast/readability, accessibility sizes, VoiceOver and reduced motion. Use shared SwiftUI theme tokens rather than per-screen hard-coded style so changes propagate app-wide.
- Design presets stored locally and sync optional appearance tokens to Watch; support system accessibility and reduced motion.
- Make it feel like the owner's app while letting other users choose different personalities.

## Phase 4 — Motivation (opt-in and source-selectable)
- Dedicated Motivation area, a compact daily quote/card, a journal/favorites collection, and optional reminders.
- Independent content source choices: Scripture references, original secular discipline/hard-work writing, sport/performance prompts, user-written motivation, or disabled.
- Scripture translation preference: ESV or LSB when rights/availability permit. Use references and properly licensed content; do not assume religious content should be visible to everyone.
- Personalize tone (quiet, direct, rigorous) and daily timing; respect reduced notifications and privacy.
- Preserve the strong black-and-white print style of previous motivational posters as one optional visual treatment.

## Later integrations
- Review existing HealthCoach/WHOOP workout histories and Apple Health data with source labels and deduplication.
- Support running plans, recovery and readiness insights only when reliable source data is present.
- Do not invent recovery measurements.

## Acceptance criterion for each stage
A code merge or successful Xcode compile is not a device test. Verify actual version, live device installation, action outcomes, and data persistence on both devices before saying a feature is fixed.
