# iMun Build 50 — Unified Workout Sync

## User promise and limits
Phone and Watch are **peers**, not a watch-only accessory. Each records sets,
runs and undo/correction events locally first, using stable UUIDs, then uploads
to the same authenticated, owner-scoped Command Center cloud records. The other
device reconciles those durable records promptly while in the foreground. A
reachable companion gets a lightweight wake-up hint **after** the write
succeeds; no health data, workout content, or authentication credentials are in
that hint. Missing companion registration does not disable cloud sync.

Foreground target: a few seconds for live notifications; a typical polling
opportunity of ~6 seconds on active Watch workouts, ~6 seconds for active
iPhone workouts, ~12 seconds for Watch schedule changes during training, and
less frequent reconciliation while idle. **Not a guaranteed delivery SLA.**
Network outages, iOS/watchOS suspension and battery-saving policies can delay
delivery until the next allowed refresh or app opening. Pending local events
must remain available and retry when connected.

## Routing
| Data | Authoritative record | Fast path | Offline path |
|---|---|---|---|
| Completed set / corrected set | UUID-scoped cloud workouts + local pending | WCSession event or post-commit nudge when reachable | Durable cloud upload, peer foreground read |
| Undo / workout correction | UUID-scoped cloud correction + local pending | WCSession event or post-commit nudge | Durable cloud upload and read; never re-count undone sets |
| Prescribed strength / run plan | Dated authenticated published schedule | WCSession application context | Cloud schedule read, foreground more frequently during workout |
| EITAN wellness | Phone calculated, same-source authorized Health data | WCSession latest-state | Explicit user-consented private snapshot via owner's cloud account |
| Active timer state | Owning device local timestamps | WCSession status when reachable | Not represented as a synchronized background stopwatch; no fabricated active set |
| Appearance preferences | Local athlete settings | WCSession latest-state | Existing optional cloud appearance |

Local progress always updates immediately. If an event has not reached cloud,
its status must not be called "synced." The UI distinguishes live iPhone link,
cloud-account sign-in, current cached records, and pending uploads.

## Apple companion registration
App targets share one iOS companion bundle identifier:
  iPhone: com.dylaneh7.HealthCoachNative
  Watch: com.dylaneh7.HealthCoachNative.watchkitapp
The modern single-target Watch app is embedded into the phone's PlugIns
directory by the HealthCoach scheme, with companion Info.plist key referencing
the iOS bundle ID. The Watch can run independently (cloud route) but still
uses WatchConnectivity opportunistically.

A developer-run Watch scheme by itself may not update the iPhone companion
installation. **Never delete or reinstall these apps as a first diagnostic**:
uninstalling deletes locally queued workout data. For physical testing, install
the same signed Build 50 on iPhone and Watch, preserving both apps' local data.
Inspect the Watch EITAN detail for the installed Watch bundle ID and declared
iPhone companion ID. An unregistered companion is a direct-link issue, *not*
proof the cloud workout record failed.

## Native acceptance tests

- [ ] Xcode native iOS and watchOS compilation succeeds for Build 50, including
      Watch embedded in HealthCoach iOS application
- [ ] iPhone/Watch both have matching version/bundle IDs, team signing
- [ ] Both devices signed into the same iMun account; cloud status connected
- [ ] With both apps foregrounded, phone logs one set; Watch reflects within
      the next live message or short cloud check, not duplicate sets
- [ ] Watch logs one set; iPhone Today AND Training update without manual refresh
- [ ] Same-UUID correction propagates; immutable historical event preserved
- [ ] Undo on either device removes visible set count on the other
- [ ] A second overlapping set on same prescribed slot does not double progress
- [ ] Start and finish a run; durable run data eventually appears on both,
      while active Watch timers remain local when direct link is unavailable
- [ ] Change today's iPhone prescribed run / workout and confirm Watch fetch
      takes effect without stomping an ongoing logged Watch session
- [ ] Turn Bluetooth off while preserving cloud internet and confirm workouts
      still reconcile, even if "Live iPhone: unavailable"
- [ ] Offline on Watch: local sets/undos persist across relaunch and upload once
      connected; no duplicates on reconnection
- [ ] Offline on iPhone: same as Watch
- [ ] App backgrounded/locked: no false promise of continuous low-latency sync
- [ ] EITAN private-cloud opt-in remains OFF by default and switching it OFF
      clears server-held Health details as designed
- [ ] Normal training cloud sync never silently enables EITAN cloud consent
- [ ] Diagnostics distinguish Cloud status, direct paired registration,
      and latest loaded cloud progress
