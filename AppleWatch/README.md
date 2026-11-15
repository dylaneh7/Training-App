# IMUN — Strength, Running & Recovery

IMUN is the native iPhone and Apple Watch app. The Home Screen name is **imun**.
Its identity is intentionally simple: dark charcoal, an ivory **im** monogram,
and a restrained crimson accent. The Coach screen contains
**1 Corinthians 9:24–27 (KJV)** as an optional expanded reading.

## Everyday use

- **Strength:** shows today's lifting plan. Adjust reps, weight and RIR
  on iPhone or Watch, record sets and use the rest timer. No date picker.
- **Run:** shows today's planned run and recorded result. Older running results
  remain accessible below. No date picker.
- **Progress:** shows future training days, running volume, exercise progression,
  recorded strength sets and prior workouts. Tap **Move day** to choose a date,
  or **Today** to move an upcoming session to the current date.
- **Schedule editing:** updates your signed-in Command Center planner through
  user-scoped database functions. Strength rotation templates become real
  planner entries when moved; past recorded workouts keep their dates.

## Personal history and permissions

1. On iPhone, sign in with your existing **Health Coach / Command Center**
   account. IMUN reads the original planner, hybrid-coach history, completion
   events, Watch sets, running sessions and daily recovery records.
2. In **Coach → Connected training history**, review the imported counts and
   optionally export your original source archive, stored locally on iPhone.
3. In **Coach → Tredict / Garmin**, create a read-only Tredict personal API
   token from Tredict → Settings → Personal API with activityRead and
   bodyvaluesRead scopes. Enter it **on your phone**, not in chat.
   Tap **Connect & Import History**. IMUN imports paginated activity summaries,
   HRV/sleep, body measurements, capacity and equipment where available, and
   archives the original response locally. Extended metrics include pace,
   heart rate, power, cadence, elevation and lifting totals when supplied.
   The Tredict token remains in iPhone Keychain, not Command Center.
4. If your Garmin data is missing in Tredict, connect Garmin under Tredict →
   Settings → Services. Tredict offers an automatic import of roughly two
   years of Garmin activities and a manual upload path for older Garmin exports.
   [Garmin-to-Tredict instructions](https://www.tredict.com/faq/garmin-connect---how-to-connect-and-synchronize-my-device/)
5. In **Run → Connect Apple Health**, grant workout-reading permissions on your
   physical iPhone. Completed Apple Workout runs and WHOOP workouts actually
   written to Apple Health can be imported, but not every metric is available
   from every source.

Automatic HealthKit background delivery requires physical-device testing.
Full Tredict/Garmin history cannot be downloaded without the user's token
and connected Garmin data. Raw original workouts are never replaced by
fabricated metrics. Existing bundle identifiers are retained so an app
upgrade can preserve its local data.

**Install:** download the latest repository ZIP and open the Xcode project
at AppleWatch/HealthCoachNative.xcodeproj. Select your Apple signing team;
run **HealthCoach** on the physical iPhone. The Home Screen displays **imun**.
Install its companion via the iPhone Watch app, or run the HealthCoachWatch
scheme on your paired Apple Watch.

---


## Current IMUN workflow (native 2.2)

**Today-only Strength and Run:** no daily date selector. These tabs show the current workout automatically. The Progress tab shows recorded progress and the next 30 days of saved Calendar entries and repeating Push/Pull/Upper/Legs program previews.

**Move workouts yourself:** select a workout in Progress and tap **Move day** or **Today**. The authenticated `imun_move_planned_workout` / `imun_move_rotation_workout` RPCs update only the signed-in user's Command Center planner. Synthetic rotation previews become real dated events on a successful move; the old recurring occurrence is suppressed. Historical completed workouts and sets are not moved.

**Recorded legacy data:** IMUN reads existing Health Coach workout sets, saved planner sessions, source-labeled Tredict/Hybrid Coach activities, running results, and Tredict recovery. It keeps the original legacy planner and workout state alongside normalized activity/recovery records in a private local archive, with user-triggered export in Coach.

**Direct Tredict + Garmin history:** Coach → Tredict / Garmin accepts a *Personal API token* obtained in Tredict Settings → Personal API, with read-only `activityRead` and `bodyvaluesRead` scopes. The token stays in the iPhone Keychain, is never committed to GitHub, and is not forwarded to Command Center. Manual Sync All History downloads paginated activity summaries (up to 15,000 per sync), HRV, sleep, body measurements, capacities and equipment details where authorized; original response JSON stays on the iPhone. Users can disconnect/re-import, and missing permissions produce partial data rather than invented measurements. A valid token and Tredict subscription access are required; no unseen Tredict history is accessible until the owner connects.

Official Tredict API: https://www.tredict.com/blog/oauth_docs/ 
Official Tredict Garmin setup and older-history import: https://www.tredict.com/faq/garmin-connect---how-to-connect-and-synchronize-my-device/

**Brand:** Home Screen display name **imun**; minimalist off-white “im” on charcoal with a crimson accent, with optional alternate accent palettes. The inspiration is 1 Corinthians 9:24–27, with a short quotation in Coach. Native bundle identifiers remain unchanged so upgrading replaces the prior app.

**Limits:** Direct Garmin time-series details and exact Tredict data availability depend on the source API and what has been authorized. IMUN currently imports the activity-list summaries and archives other supported Tredict responses; it does not automatically fetch every raw FIT file, lap, or GPS point. A successful CI simulator build does not replace testing on the user's paired devices.


A standalone **native SwiftUI iPhone/watchOS companion** for the existing Health Coach web app. This folder is kept separate from the web app, so nothing here replaces your PWA or its workout history.


## Apple Health + WHOOP automatic run import (2.1)

On a **physical iPhone**, open **Run → Connect Apple Health** and allow reading workouts plus available running measurements. After you opt in, Health Coach checks saved running workouts during app launches/foreground returns and via a HealthKit workout observer. The iPhone HealthKit Background Delivery entitlement is enabled for supported development provisioning; true wake-up behavior still requires device testing.

- **Apple Workout:** finish and save a Running workout using Apple's Workout app. The iPhone Health app must receive the workout before Health Coach can import it.
- **WHOOP:** in WHOOP settings enable the Apple Health integration and enable WHOOP to **write Workouts** and supported measurements to Apple Health. WHOOP supports exporting auto-detected workouts, but Apple Health does not necessarily receive WHOOP's full proprietary workout analysis or routes.
- **Run details:** see date, original source, elapsed time, distance, pace, average/max HR, calories, running power, cadence, elevation, actual lap events, and—in recently imported workouts, when present—attributed heart-rate samples and GPS route points. Missing data displays as missing, not generated values.
- **Native schedule:** an imported run from a scheduled date marks that run complete in the local Health Coach view. Provider completion is not automatically written back to the external Command Center calendar; this feature does not promise a bidirectional sync.
- **On Watch:** updated run summaries and the selected run plan arrive through WatchConnectivity after the iPhone's Health Coach app sends its context. GPS traces and detailed HR series are deliberately excluded from the watch transfer and remain on the iPhone.

Deduplication compares HealthKit workout IDs and close matching dates/start times/distances/durations where legacy sources lack a shared ID. WHOOP and Apple can both export a single workout, so validate source attribution before trusting a duplicate.

**Do not test automatic HealthKit background delivery in the simulator.** Apple requires testing that part on a real device. If your free Personal Team provisioning profile does not support the background-delivery entitlement, remove that capability for a foreground-only prototype or use the appropriate Apple Developer membership; continue to test the native timers normally.

## Health Coach 2.0 native redesign

The iPhone entry point now loads **PremiumHomeView** with a unified premium dark palette and five deliberately designed tabs:

- **Strength:** session overview, timer, completed-set/volume metrics, fast set weight/reps/RIR adjustments, personalized suggestions, workout editor and exercise library.
- **Run:** today's planned run, optional completed splits, pace, distances and prior sessions.
- **Progress:** per-exercise load and running mileage charts based on actual recorded data.
- **Recovery:** Apple Health measurements (including WHOOP-sourced readings when available), plus source-labeled Tredict history. Incompatible HRV types are not mixed.
- **Coach:** progression preference, private coaching notes, user-initiated AI export, sync visibility and account controls.

The Apple Watch app now uses a separate wrist-optimized interface with prominent strength/run start controls, a persistent workout timer, per-set Start / Stop & Save, rest countdowns and haptic notification, and manual run laps. Offline event storage and cloud bridges are unchanged.

### Updating the Mac copy

**If you previously downloaded a ZIP:** the files on your Mac do not auto-update. Download a new ZIP from the repository, unpack it and open the new \`AppleWatch/HealthCoachNative.xcodeproj\`. Select your signing team if prompted, and Run again to replace the installed build.

**For future edits:** clone this repository through Xcode Source Control or \`git clone\`. Then subsequent assistant commits can be received with \`git pull\` instead of redownloading the whole archive.

A code commit or a successful simulator build is not proof of usability on a real Apple Watch. Check workout starts, set-saving, heart-rate permissions and watch-to-phone delivery on paired devices. If a new screen doesn't load, ensure Xcode is opening the latest copy of the repository.

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

## Watch/iPhone schedule consistency (sync update, Nov 2026)

The iPhone is the source of truth for the **current date's** plan. The Watch is
an extension of that app, not an independent scheduler:

- The phone sends one date-stamped `HCWatchSchedule` object through
  `WCSession.updateApplicationContext`; it explicitly includes `nil` when
  there is no strength workout or run. An empty plan is a valid rest day.
- The watch never starts with the old November 14 sample lift. Cached plans
  must match the **current local date** to appear. Yesterday's workout cannot
  appear as today's scheduled session.
- Opening the Watch app requests its latest schedule from the paired iPhone.
  The iPhone sends its current state and, when online, refreshes the cloud
  calendar and pushes a subsequent update.
- While the iPhone app is foregrounded, it checks the Command Center every
  minute. Edits made on the iPhone are pushed immediately. watchOS/iOS may
  delay delivery while the iPhone is offline, suspended, or out of reach.
- Set and run completion records use an immediate WatchConnectivity message
  when reachable *and* a durable background transfer for eventual delivery;
  the iPhone deduplicates by UUID.
- Active strength sessions remain available through temporary connection
  loss and are not discarded when another device edits the day's plan.

**To install the fix:** update **both** the `HealthCoach` iPhone app and the
`HealthCoachWatch` Watch app from the same Xcode project. Updating the Watch
alone does not give the old iPhone app the new dated schedule protocol.
The source ZIP does not install or update apps on devices by itself.

**Validation checklist:** On a rest day, iPhone Strength and Watch Strength
must both say no workout is scheduled. Move a planned session onto today on
iPhone and reopen/refresh the Watch: it should appear. Move it off today:
the Watch should remove it. Record a set on Watch and verify the iPhone's
log reflects the same set without duplicating it. Test offline and date
rollover separately; background delivery is not guaranteed to be instantaneous.
