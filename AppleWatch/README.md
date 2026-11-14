# Health Coach — Native Apple Watch App (MVP Source)

This is a **separate native SwiftUI starter** inside the existing Health Coach repository.
It does not change the installed Health Coach web app or its saved logs.

## Included

- Apple Watch exercise list with sets/reps and optional suggested weight.
- On-watch logging of weight and reps, with an offline JSON backup on the watch.
- Paired iPhone app that sends an example workout and receives logged sets using WatchConnectivity.
- Deduplication of received sets by UUID.
- Shared Codable workout models with stable exercise IDs.

**Not yet implemented:** authenticating against Health Coach / Supabase, retrieving live training plans or prior-set targets, writing logged sets back to Supabase, Apple HealthKit workout sessions, live heart rate, rest timers, and publishing to the App Store. The included full-upper workout is **demo data**, not an automatic live schedule. No weights are invented.

## Create the native project in Xcode

Apple requires Xcode on a Mac for building and signing a native watchOS app.

1. In Xcode, create **watchOS → App → Watch App with New Companion iOS App**. Use the project name `HealthCoachNative`.
2. Replace the Xcode template watch app entry point with `Watch/HealthCoachWatchApp.swift` and its initial view with `Watch/WatchWorkoutView.swift`. Add `Watch/WatchWorkoutStore.swift` to the watch target.
3. Replace the template iPhone `@main` app and initial view with `iPhone/HealthCoachPhoneApp.swift` and `iPhone/PhoneContentView.swift`. Add `iPhone/PhoneWorkoutBridge.swift` to the iOS target.
4. Add `Shared/WorkoutModels.swift` to **both** iOS and watchOS target memberships.
5. Delete or remove target membership from the Xcode-generated duplicate `@main` app files. Every target must contain exactly one `@main` application.
6. Choose your own unique bundle identifier (the watch target should use the iOS bundle identifier as its prefix). Set a Development Team under Signing & Capabilities.
7. Build the iPhone and watchOS schemes, install both on a paired iPhone and Apple Watch, and allow them to communicate.
8. Open the iPhone app and tap **Send Demo Workout to Watch**. Open the watch app, pick an exercise and record a set. The iPhone app should display that set when WatchConnectivity delivers it.

Use **Apple's Xcode-generated project** for build settings, entitlements and watch embedding rather than making a legacy WatchKit project by hand.

## Data flow

```
Health Coach (existing PWA + Supabase) [future live sync]
              |
              v
iPhone companion -> WCSession application context -> Watch workout
iPhone companion <- WCSession queued user info <--- Logged sets
              |
              v
Health Coach cloud set logs [future secure API]
```

The watch app persists sets before requesting transport. WatchConnectivity can deliver queued transfers when devices reconnect, but end-to-end cloud acknowledgement and retry logic are **future work**. The iPhone currently keeps received sets in its own local JSON file.

## Next integration milestones

1. Authenticate the iPhone app with the existing Health Coach account using a supported sign-in flow; use Keychain for any tokens. Never embed privileged Supabase keys in either app.
2. Return today's actual workout from a **user-authorized backend endpoint**, including stable exercise IDs and approved progression targets.
3. Accept watch-origin set logs through an idempotent server endpoint that writes only the relevant workout/set (not a replacement of the full cloud JSON).
4. Add watchOS HealthKit `HKWorkoutSession` and `HKLiveWorkoutBuilder` for traditional strength training, heart-rate display, and Apple Fitness workout records after permissions are granted.
5. Add rest countdowns, haptics and Digital Crown adjustments, then test on the actual paired devices.

## Notes

- `HCWorkout.preview` is an example from the November 14 full upper-body session.
- No third-party strength app or Hevy subscription is required for this native approach.
- The source files have not been compiled or signed in Xcode in this environment; actual watchOS compatibility must be validated in Xcode on a Mac.
