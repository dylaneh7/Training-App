# Build 62 — Motion intelligence / source-specific lifting

## Shipped in this development branch
- Apple Watch Core Motion observes 25-Hz wrist acceleration and angular rate only during an active strength set. No raw motion frames are uploaded.
- Motion cycle estimates fill the **normal editable reps field**. The Watch-owned per-set draft survives navigation and is saved locally. User +/- adjustment takes precedence over later detected cycles. Set completion remains a deliberate confirmation.
- Interrupted Watch sessions retain the last local count but freeze auto-update rather than pretending the missing sensor interval was captured.
- Unilateral exercises have **physical side-specific numbered slots**: 6 total means Left 1, Right 1, Left 2, Right 2, Left 3, Right 3. No automatic increase in weight or completed-set creation.
- iPhone exercise editor supports bilateral/unilateral overrides and side-specific manual logging; IsAIah edits must use equal left/right set counts.
- Watch and iPhone Settings record Apple Watch and WHOOP positions. The iPhone sends time-versioned motion preferences to Watch using the existing WatchConnectivity context.
- Compact per-set motion estimates track cycle duration, late-cycle slowdown, and relative wrist-motion intensity; descriptions call these **proxies**, not verified form or anatomical range of motion.
- IsAIah receives these compact observations only when the athlete deliberately sends an online coach message, subject to existing chat consent. The displayed source and working side stay explicit.

## Verified external benchmark: Gymatic feature list
Gymatic publicly advertises exercise recognition, rep counting, auto work/rest tracking, velocity, power, tempo, rep speed, form/range/speed consistency, workout heart rate and calories, guided/freeform workouts, custom exercise training and 1RM estimates. Source: https://apps.apple.com/us/app/gymatic-workout-tracker/id1036069872

| Capability | iMun Build 62 | Next validation/research |
| --- | --- | --- |
| Rep count on active Watch | Experimental automatic count and manual override | Per-exercise calibration, false-positive/negative evaluation |
| Per-set work/rest | Existing workout timers and rest alerts | Motion-derived start/end detection, opt-in only |
| Per-rep timing | Experimental wrist cycle duration and last-cycle comparison | Tempo phase segmentation and ground truth labels |
| Range consistency | Only relative wrist-motion intensity proxy | Integrate calibrated angular path; cannot call this joint ROM |
| Rep speed / velocity | Only wrist cycle timing; **no actual bar velocity** | Additional hardware + validation |
| Power | Not measured | Requires force/load × actual movement velocity; weight/reps alone insufficient |
| Form consistency | Not measured | Exercise-specific calibrated multisensor comparisons; avoid injury claims |
| Two-arm comparison | Data model and side source attribution only | Requires independently accessible second synchronized live motion source |
| WHOOP gyroscope/accelerometer | **Unavailable via the official developer API** | Supported live data access or independent approved Bluetooth IMU |
| Exercise recognition | Not yet implemented | Supervised labeled exercise-classifier and manual correction |
| Workouts / 1RM | Existing iMun planned workouts and performance history | Separate evidence-based 1RM estimates and quality flags |
| Apple Watch HR and calories | Existing HealthKit workout session | Trust HealthKit's actual measurements, don't invent set-level values |
| Guided/freeform workouts | Guided session exists | Freeform live motion classification needs separate development |

WHOOP published integration/export documentation: https://www.whoop.com/us/en/thelocker/access-your-whoop-data-with-new-integrations-data-export-options/
WHOOP API: https://developer.whoop.com/api/

## QA before merge

1. Native iOS and watchOS targets compile. Confirm bundle compatibility and that Build 61 haptics, notifications, app startup and background sync still work.
2. Start a guided unilateral one-arm row, six total slots. Watch on left: left side detects; right side does **not** falsely apply the left wrist signal. Reverse when Watch position changes.
3. One-sided exercises are individually selectable out of order, with one completed set per numbered slot. Undo on either device must keep the correction.
4. Start an automatically advancing set after rest. The normal reps field must update without any 'USE' action. Do not auto-complete or override a user-edited count.
5. Navigate away and back while motion is active. Preserve the editable store-owned count and manual lock. On Watch process termination/relaunch, restore the count and require manual follow-up rather than fabricating missed cycles.
6. Ensure non-motion exercise, unavailable Core Motion, Watch not on working wrist and user-disabled setting continue using manual rep entry.
7. iPhone / Watch sync and cloud corrections: preserve recorded set UUIDs. Confirm no duplicate progress after reconnection and no unrelated training records overwritten.
8. Compare slow final reps and varied wrist-motion signals against video-labeled ground truth. Never display form, exact ROM, true velocity or force without external validation.

## Not production-ready / separate milestones
- **Source adapter:** hardware-independent timestamped IMU interface that can ingest Apple Watch and a later authorized second wearable. Need clock synchronization, source labels, sampling confidence, disconnect recovery.
- **Motion metrics v2:** per-rep eccentric/concentric timing, hesitation detection, repeated-cycle similarity, confidence and calibrated direction-aware wrist angular excursion.
- **Learning:** supervised exercise enrollment/classification; exercise-specific thresholds and user correction feedback; false-positive safeguards for spotting, racking and setup.
- **History:** persistent user-owned structured motion insights with schema migration and authenticated row-level security; careful retention, export and deletion controls. The current cloud set schema does not yet persist the motion payload.
- **Two-wrist comparison:** only after a real second live IMU stream exists. WHOOP Recovery/Sleep/Strain/Workouts are separate from raw motion and must never be mislabeled as live gyroscope data.

Do **not merge** solely because the static preflight passes. Requires native CI and physical-device validation.
