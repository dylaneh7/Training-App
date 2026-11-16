# imun — Watch single-screen guided strength

## Why this update
A watch strength session previously required tapping **Start Workout**, then opening/starting each set, saving each set, navigating to choose another exercise, and opening an options screen. This is too many screens and controls for lifting.

## New Watch interaction
1. Open Strength and tap **START WORKOUT** once. The first unfinished prescribed set starts immediately and the Watch's HealthKit strength session begins.
2. Weight, reps and RIR can be adjusted on the same scroll view. Tap **NEXT · SAVE SET** once to complete the active set. It is persisted with its actual exercise and prescribed set number, including start/end timestamp, weight/reps and RIR.
3. The assigned rest time for the **set just completed** starts automatically. The next set is chosen from the still-unfinished prescription, normally continuing the same exercise before proceeding in schedule order.
4. When the rest timer expires, the next chosen set begins automatically without pressing **Start Set**. The clock uses wall time so a wrist-down/display wake does not reset it. A haptic indicates that the next set has begun; **SKIP REST** immediately advances when desired.
5. **CHOOSE ANY SET** expands an in-place workout overview with all exercises and individually numbered sets. Completed sets are disabled/checkmarked. Any remaining set can be selected out of order:
   - While a set is active: the chosen set appears as **UP NEXT**, so recording is not interrupted. If the planned machine is busy before a set has actually been done, use **SWITCH NOW · NO SET LOGGED** to abandon only the unrecorded current timer and start the newly selected set immediately.
   - During rest: selection changes what starts after rest (or upon Skip Rest).
6. A whole-workout progress indicator shows completed/prescribed sets. Pause, Resume and Finish are available directly in the main workout screen, without a separate options page.
7. Existing logged sets, watch running, WatchConnectivity record IDs and the iPhone cloud history are preserved. A session pause also freezes the prescribed rest countdown.

## Engineering and compatibility
- `HCTrainingClock.setNumber` is optional so previously saved clocks decode.
- `HCGuidedSetChoice` stores the selected exercise/set and optional queued-next choice. These choices are cleared at appropriate workout boundaries.
- Individual set `index` reflects the **actual prescribed set selected**, not the number of preceding recorded sets. Duplicate or out-of-range prescribed set numbers cannot be logged.
- `stopSet` continues to save workout records locally and use existing guaranteed Watch-to-iPhone pending transfers, including latest sync repair.
- This is a Watch-target source change only. The existing iPhone app can stay installed, but the updated Watch app must be built and installed with Xcode.

## Device checks
- Verify first set auto-starts on Start Workout.
- Save with Next: one record is logged; the prescribed rest begins; the next set starts automatically after the real elapsed interval, with no extra tap.
- Pick a different exercise's set during rest; confirm it starts when the rest ends.
- Pick a different set during an active set; confirm it queues for Next. Use Switch Now on an unperformed current set; confirm no false set record exists.
- Pause during rest and resume; check that rest duration is preserved.
- Complete all prescribed sets, finish the session and confirm each record arrives in iPhone/cloud with its selected set number.
- Verify existing Watch Refresh and Send to iPhone still work and no recordings have been discarded.
