# imun — iPhone + Apple Watch Continuous Strength and Exercise Swaps

## One feature set, two native apps

The **iPhone** and **Apple Watch** now share the same planned workout and exercise matching rules. There is no web-only feature or Watch-only exercise swap.

### During a workout
- Start on either device to begin the first prescribed set.
- **Next · Save Set** logs that actual set, then starts the exercise's prescribed recovery period.
- When recovery ends, the next unfinished set can begin automatically, and the rest countdown survives normal screen navigation.
- Expand **Choose Any Set** on the workout screen to jump around busy equipment. A choice made during an active set becomes **Up Next**. **Switch Now** discards only an unlogged active set timer.
- Progress is measured from actual completed set records, not an invented score.

### Easy same-muscle substitutions on both devices
- The iPhone Training lineup has **Swap · Same muscle** on each exercise. The in-workout guided panel has **Swap exercise** too. The Watch guided workout also has **Swap Exercise**.
- Suggested substitutions come from the shared exercise library and are matched by primary muscle/movement: chest, lats, back, biceps versus triceps, quad versus hamstring, rear versus side delts, and more. This is a practical heuristic, not an anatomy guarantee.
- The replacement keeps the workout identity, exercise slot ID, set count, rep range and planned recovery period. The load is intentionally **reset**, because machines, cables, dumbbells and barbells are not interchangeable load prescriptions.
- Sets previously completed stay saved with the **exercise actually performed**, even when the planned slot is later swapped. Future sets are recorded under the new name. No existing recorded work is changed or erased.
- Both devices offer **Undo** for the most recent local swap.

### Synchronization and offline operation
- iPhone substitutions update the authoritative planned workout, save locally, then sync the plan to Command Center and Watch through existing sync.
- Watch substitutions immediately change its local workout and are persisted as individually identified events. They transfer via immediate WatchConnectivity when reachable, with background `transferUserInfo` fallback. iPhone accepts each replacement only for its current matching workout/slot, saves it locally, and sends the updated plan back. If a newer conflicting iPhone edit exists, the iPhone's actual plan wins rather than silently reverting it.
- Every saved set retains its prior record ID and can still use the existing Watch-to-iPhone upload queue. An offline Watch restart restores the substitution before applying its cached workout.
- iPhone and Watch must both install this source update once from the same GitHub `main` release. **Do not delete the Watch app** to update it, since it may contain unsynced workout records.

### Physical-device acceptance checks
1. Verify one tap Start, Next, rest, and auto-next on iPhone and Watch separately.
2. Open **Choose Any Set** and select a different unfinished set. Confirm completed sets remain checkmarked.
3. On both apps, select **Swap Exercise** and choose a same-muscle alternative. Verify the new movement name, prescribed reps/rest and a reset starting weight.
4. After logging one set of the original exercise, swap to another and log another set. Confirm workout history preserves both actual movement names.
5. Check undo and offline / reconnect behavior. Watch replacement should appear in the iPhone workout without changing previously completed set records, and phone replacement should appear on Watch after syncing.
6. Verify previous Refresh and Send to iPhone buttons continue to work.

Build checks compile both native targets in Xcode simulators. Physical WatchConnectivity delivery, background-rest timing and Bluetooth/wrist-down operation still require testing on personal devices.
