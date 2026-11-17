# iMun visual foundation — Build 32

## Product direction

**Editorial performance software, not a novelty dashboard.** The interface should feel designed around the athlete's actual data and tasks. A successful screen can be understood in five seconds without decorative labels, icons or manufactured summary scores.

### Visual rules

1. **Hierarchy before decoration.** A page introduction establishes purpose and context. Section headings are typographic. The accent is not a substitute for hierarchy.
2. **One metric, one place.** Health uses one card per measurement family; independent sources are rows inside the same card. Sleep and HRV are no longer exceptions.
3. **No fabricated composite measurements.** WHOOP RMSSD and Apple Watch SDNN appear within one HRV section but retain clearly labeled methods and independent baselines. There is no single blended HRV value, recovery score or source-averaged sleep.
4. **Charts are secondary.** The current value, measurement type, source, date and baseline comparison appear first. Historical charts open on demand.
5. **Calm surfaces.** Flat cards, subtle boundaries, restrained radius and consistent spacing. No full-page grid/glow patterns, fake telemetry rings, heavy gradients or repeated theme emblems.
6. **Deliberate accents.** Color identifies actions, selected controls or meaningful metric deviations. Data cards are neutral even if a caller supplies a theme accent.
7. **Personalization without inconsistency.** All eight themes keep their palette, editorial headlines, and intentional motif destinations. Navigation, type scale, spacing, data treatment and interaction rules remain shared across themes.
8. **Compact, readable controls.** 44+ point tap targets where possible, plain wording, SF Symbols only when the icon explains the action, no repeated decorative arrows.

### Layout tokens

- Screen gutters: 18 points iPhone; deliberate vertical rhythm of roughly 11–24 points
- Primary page titles: 32–34 point semibold, with restrained negative tracking
- Sections: 18 point semibold (serif only for Heritage/Atelier)
- Body: 13–14 point neutral system type
- Metadata: 10–12 point neutral/secondary, never the only label for source/measurement
- Data values: 23–28 point semibold, monospaced digits for stable layout
- Card border: neutral outline below 50% opacity; no colored gradient fills
- Card radius: up to 14 points, keeping established theme silhouettes where intentional
- Animations: brief transitions only when they communicate state, honoring the existing reduced-motion control

## Health grouping verification matrix

| Input | Expected card | Distinct rows / comparisons |
|---|---|---|
| Apple Watch HRV · SDNN + WHOOP HRV · RMSSD | **Heart rate variability** | Two source rows, two methods, two separate baselines |
| WHOOP RMSSD from both recorded-source history and Apple Health import | **Heart rate variability** | One canonical WHOOP/RMSSD row chosen from the freshest source record; raw provenance remains accessible |
| Apple Watch + WHOOP sleep hours | **Sleep** | One card, source-separated hours, no averaged hours |
| Two apps returning Apple Watch resting heart rate | **Resting heart rate** | One Apple Watch row based on the latest dated reading |
| HRV and resting heart rate both flagged | Separate metric cards | Two metric categories, each with discreet source-specific comparison |
| WHOOP category filter | Same metric-family grouping | WHOOP-only rows, never Apple Watch values |
| Search `hrv` / `WHOOP` | Matching relevant metric cards | No duplicate outer card for each matching source |
| No baseline or no HealthKit authorization | Empty/provider state | No made-up score, no inappropriate negative verdict |

**Caution:** Daily summaries are derived from samples as before, and existing raw HealthKit/source data is not modified or erased. Grouping changes presentation only.

## Scope and release safety

Build 32 is stacked on Build 31; it **does not** change the proven Build 30 iPhone/Watch companion pairing, cloud schedule transport, WorkoutKit export behavior, HealthKit permissions, recorded workout schema or data-sync functions. Only iPhone SwiftUI presentation and shared visual background token behavior are changed.

Do not merge until macOS Xcode compiles the stacked iPhone/watchOS branch, and inspect the result on physical iPhone at larger Dynamic Type sizes. Also verify all eight themes in light/dark where supported. Watch UI remains functionally unchanged.
