# Build 47 — EITAN Watch connection and data diagnosis

## What was actually wrong

Previous versions constructed EITAN context twice: once for workout-schedule
transfers and once for standalone wellness delivery. Each construction invented
a fresh timestamp even when the content had not changed. This allowed a
schedule update to carry an old/empty EITAN score with a newer timestamp than
the correct wellness packet. The Watch then ignored the correct packet as
stale. Old queued EITAN user-info receipts also created additional
WCSession transfer timeout logs.

Build 47 uses a single stable content revision, reuses it in both places,
keeps background application-context delivery replaceable, and sends a live
message only when needed. The Watch shows diagnostic status, decode reason,
protocol version, payload size, and installed app build numbers.

**Important:** the Xcode console text "WCErrorCodeTransferTimedOut" is an
OS-level transport timeout. It does not uniquely identify an EITAN transfer.
Workout/userInfo transfers or older queued packets may still produce that
log even if EITAN's latest-state snapshot succeeds.

## Physical-device verification (two installed targets required)

1. Quit both apps and verify the selected Git branch is current main at
   Build 47. Confirm the signing team on HealthCoach, HealthCoachWatch and
   the widget target; do not remove local signing overrides unnecessarily.
2. Select **HealthCoach** iOS scheme and the **paired iPhone** destination
   in Xcode; Run to install the new **iPhone** app. Open the app and leave it
   foregrounded on the **Today** tab.
3. Select **HealthCoachWatch** watchOS scheme and the paired **Apple Watch**;
   Run to install the new Watch app. With both app screens visible,
   tap **EITAN** → **SYNC EITAN FROM IPHONE** on Watch.
4. The Watch detail should show **WATCH BUILD 47 · PHONE 47** or other
   matching build values. If PHONE reads "older iPhone build" or a different
   number, the paired iPhone app is not the same release; reinstall via the
   HealthCoach iPhone scheme, not only the Watch scheme.
5. Read the **EITAN status and transport details** on Watch:
   - "No valid EITAN packet" = outdated/missing iPhone payload
   - "iPhone did not answer live request" = open iPhone iMun and confirm pairing
   - "Could not decode EITAN" = model/version mismatch; details contain error
   - "EITAN belongs to [date], not today" = stale daily data
   - "EITAN synced · building personal baseline" = **transport worked**
     but enough source-specific physiological readings aren't available yet
   - "EITAN score synced from iPhone" = **transport and scoring worked**
6. On iPhone **Today**, confirm "iPhone wellness" is a number or shows
   "baseline incomplete", separately from Watch connectivity status.
7. If iPhone itself shows "baseline incomplete", inspect **Health →
   source**, selected primary wearable, and the EITAN coverage explanation.
   WHOOP HRV is not exported to Apple Health and must not be replaced by
   Apple Watch SDNN. This is a missing-data issue, not Watch transport.
8. Open **Settings → EITAN** to select the primary wearable and use
   **Sync EITAN to Apple Watch**. Record both screens' diagnostic statuses.
9. With iPhone locked/unreachable, verify Watch can keep its last same-day
   snapshot; status must **not** claim a new confirmed receipt.
10. Verify changing **Use Health data for EITAN** off clears private Watch
    wellness data while retaining training-only mode. Turning EITAN off
    hides the tile.

## Regression checks

- [ ] Native iPhone and watchOS targets compile
- [ ] iPhone and Watch both installed at Build 47
- [ ] Stable wellness revision across workout schedule update
- [ ] Updated EITAN snapshot changes revision once
- [ ] Background update does not queue EITAN userInfo retries
- [ ] Live request reports the actual decode/transport result
- [ ] Older EITAN background packets never overwrite newer score
- [ ] An absent WHOOP baseline shows insufficient data, not a fake zero
- [ ] Workouts, logged sets and undo records still sync separately
- [ ] Closing/reopening the Watch retains a same-day decoded wellness snapshot
