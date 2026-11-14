# Health Coach Native — iPhone + Apple Watch

A standalone **native SwiftUI iPhone/watchOS companion** for the existing Health Coach web app. This folder is kept separate from the web app, so nothing here replaces your PWA or its workout history.

## What is ready

- A **directly openable Xcode project** at [HealthCoachNative.xcodeproj](HealthCoachNative.xcodeproj), with both app targets, embedded watch app, two shared schemes, automatic-signing settings, HealthKit entitlements, and Info.plist files.
- iPhone Health Coach sign-in using Supabase Auth and tokens in **Keychain**.
- Current planned lifting session pulled from Command Center and past Health Coach workout history; current web exercise edits are preferred if the web app has published them.
- Suggested loads drawn only from recorded comparable movements (conservative return-to-training loads for the Nov 14 session). Missing weights stay missing.
- Apple Watch exercise checklist with set/rep/weight/RIR entry, on-watch rest countdown and haptics.
- Offline saved watch sets, queued WatchConnectivity transfer to the iPhone, local phone storage, and retryable **idempotent** uploads to Health Coach's database.
- Optional Apple Fitness **Traditional Strength Training** recording and watch heart rate while a workout session runs.
- Health Coach PWA publishes the currently rendered exercise plan and displays previously logged watch sets, automatically importing **only empty** set boxes. Existing PWA fields are never overwritten automatically.

## When you get to your Mac

1. Download the [Training-App repository ZIP](https://github.com/dylaneh7/Training-App/archive/refs/heads/main.zip) and unzip it. (Alternatively run `git clone https://github.com/dylaneh7/Training-App.git`.)
2. Open `Training-App/AppleWatch/HealthCoachNative.xcodeproj` in **Xcode**. Use a recent version of Xcode that supports watchOS 10 and iOS 17 or later.
3. Select the blue **HealthCoachNative** project in the sidebar. For both **HealthCoach** and **HealthCoachWatch** targets, open **Signing & Capabilities** and choose your Apple development team. If the sample bundle identifier isn't available for signing, set **HC_IOS_BUNDLE_ID** once under the project Build Settings (for example, `com.yourname.HealthCoachNative`). The watch bundle ID inherits that prefix.
4. Connect/unlock your paired iPhone and Apple Watch; enable **Developer Mode** if requested and trust the Mac. Select the **HealthCoach** scheme and your iPhone, then press **Run**. The watch app is embedded in the iPhone product; if not automatically installed, install it in the iPhone's Watch app or choose the **HealthCoachWatch** scheme and run on your paired watch.
5. On iPhone, sign in using the same **Health Coach / Command Center email and password** already used in the web app. Tap **Go to Today**, **Refresh from Health Coach**, then **Send Workout to Apple Watch**.
6. Open **Health Coach** on the Apple Watch. Tap an exercise, set weight and reps, and **Log Set**. If desired, tap **Start Strength Workout** to grant HealthKit permission and record an Apple Fitness strength workout. You can log sets even if HealthKit access is denied.
7. Open the iPhone companion to see received sets and any cloud uploads pending; open Health Coach PWA to see its **Apple Watch sets** panel.

**No Hevy, Watchletic or XcodeGen dependency is required to build the included strength app.** The `project.yml` file is a backup for regenerating the Xcode project, not a required install step.

## System details

- **Authentication:** Supabase Auth password grant with existing Command Center account; refresh tokens are stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` in iPhone Keychain. Only the **public publishable** Supabase key is present in source code. Never embed your password or a secret/service-role key.
- **Plans:** `health_coach_native_plans` is a per-user plan cache published by the signed-in PWA. The native app reads it first. When none exists, it derives a fallback from `planner_state`, the included exercise templates and `hybrid_coach_state`. **Fallback templates may not exactly match recent web swaps until you open the PWA and publish the session.**
- **Sets:** `health_coach_watch_sets` stores individual UUID-keyed watch events. Row-level security limits users to their own events. Uploads use `on_conflict=id` with ignore-duplicates so repeat transfers don't add duplicate sets.
- **Offline:** Watch sets save to an atomic local JSON file before transfer. The iPhone does the same before cloud upload. Transfers and network delivery are queued; exact delivery timing depends on Apple Watch/iPhone connectivity and background execution limits.
- **Safety:** Logging bodyweight sets supports weight=0, and weight is nullable if unknown. The system doesn't infer a missing load or claim to calculate a medical readiness score. Workout targets are suggestions, not instructions to ignore symptoms or pain.
- **Apple Fitness:** HealthKit recording runs only if you explicitly start the session and grant permissions. The set logger works independently of HealthKit authorization.

## Boundaries and testing

The source, project file, Info.plist keys, entitlement references, database tables and web bridges have been prepared without your Mac. **I have not compiled or installed this project with Xcode, tested Apple signing, or tested real paired-device WatchConnectivity/HealthKit behavior.** Those checks require your Mac, an iPhone, an Apple Watch and your development team. Apple also warns that queued `transferUserInfo` delivery requires physical-device testing rather than relying on the simulator.

To publish via TestFlight/App Store later, you will need appropriate Apple Developer Program membership, signing, app icons, privacy declarations, and App Store metadata. Local development installation is the immediate goal.

### Repository layout

- `HealthCoachNative.xcodeproj` — ready-to-open Xcode project.
- `iPhone/` — SwiftUI companion, account sign-in, Command Center reads, queued watch-set uploads.
- `Watch/` — SwiftUI watch app, set logging, timer, HealthKit workouts.
- `Shared/` — shared Codable models and prescriptions.
- `project.yml` — optional XcodeGen regeneration fallback.
- In the web app repository root: `native-plan-publisher.js` and `watch-set-bridge.js`.

## Reference documentation

- [Apple: Setting up a watchOS project](https://developer.apple.com/documentation/watchos-apps/setting-up-a-watchos-project)
- [Apple: Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity)
- [Apple: Running workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions)
