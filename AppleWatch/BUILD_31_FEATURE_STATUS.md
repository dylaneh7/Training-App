# iMun Build 31 — Health, Coach actions, wearable preview and theme sections

## This build is a first integration pass, not a WHOOP subscription replacement

### Health
- Source-preserving single Sleep card already present; WHOOP and Apple Watch show within **one** card, each with its original source label, measurement date and own baseline. Do not average incompatible sources or generate a WHOOP recovery score from Apple Health.
- Health signal/trend processing caches results and refreshes on changes to Apple Health metrics, metric history, and recovery history rather than every SwiftUI scroll/layout pass.
- New optional Bluetooth Heart Rate device card lets the athlete scan for and connect to nearby devices broadcasting the Bluetooth SIG standard 0x180D service and 0x2A37 characteristic. It displays a live BPM only; no unconsented upload, storage, HealthKit writing or background collection is enabled.
- Turning on WHOOP's Heart Rate Broadcast while an active WHOOP app is available is separate from WHOOP-specific proprietary data pairing. After membership expiration, standard BLE broadcasts may be unavailable: device test required.

### Coach AI as app controller
- Conversation accepts the following **explicit** user requests and presents a separate confirmation panel:
  - `Move tomorrow's workout to Friday` — select exact scheduled session and destination; use existing authenticated Command Center move RPC, don't change recorded workout history
  - `Mark today's run complete` — user assertion only; no fake Apple Health metrics, no fabricated running distance
  - `Sync today's workout to my Watch` — use existing Build 30 Cloud + WatchConnectivity routes
  - `Change theme to Heritage` — change only iMun appearance preset
- Coach's generative replies alone never run arbitrary Swift, SQL or external tools. The preview parses an allowlist, validates selected IDs against current planner state, requires approval, and uses preexisting trusted mutation functions. An unrecognized command remains an ordinary question to the server Coach.
- This is the **first action registry**. It does not yet support editing/deleting arbitrary workout records, creating historical metrics, changing medical data, purchasing products or full-app control.

### Theme identity
- Heritage, Retro, Techno, Coast, Field Notes, Discipline, Atelier, and Rally now use separate iconography and heading treatments across common section headers. The racing flag is only shown in Rally, not other themes.
- Existing motivation preferences and user journal remain independent of appearance.

### Remaining planned steps
1. Expand Coach with server-side structured, authenticated tool suggestions for more app features, including session creation, exercise edits, watch workout scheduling and reversible settings changes. Keep separate user confirmation for durable changes.
2. Explore direct WHOOP 4/5/MG offline protocol interoperability for user-owned hardware separately from the standard BLE heart-rate broadcast. The current independent NOOP project is source-available under PolyForm Noncommercial 1.0.0; **do not copy its implementation into a potentially commercial product without license review or permission**. Published protocol facts can inform an independent implementation. Hardware-specific, physical-device pairing and privacy tests are required.
3. Device-test the Bluetooth scan, iOS permission prompt, active sensor notifications, dropouts and disconnections.
4. Continue Health performance checks with large data sets and verify that the combined Sleep card doesn't show redundant sleep cards.

### Build and safety
- Build 31 uses the same iOS/Watch bundle IDs, mandatory companion installation, Build 30 WatchConnectivity pairing fix, and RLS-protected cloud workout schedule.
- Xcode build and real-device validation are required before declaring a working release. This environment can't run iOS/watchOS compiler or pair Bluetooth hardware.
- Do not uninstall iMun to test features: doing so can discard unsent sets, journal entries or local running logs.
- The Health tab BLE viewer does not diagnose, estimate recovery, or replace medical devices.
