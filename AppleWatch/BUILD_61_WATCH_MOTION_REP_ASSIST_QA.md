# Build 61 — Apple Watch motion-assisted reps and rest haptics

## Product behavior
- Watch uses Core Motion `CMMotionManager` fused accelerometer/gyroscope samples (25 Hz), only during an active strength set.
- Rep estimator detects a complete directional movement cycle and rejects extremely short or unusually long partial movements.
- Optional feature, off by default under Watch Settings → Training Controls → Experimental motion rep estimate.
- Displays a distinct *estimate*, plus optional measured average seconds per rep. The athlete taps **Use Estimate** to copy a proposed count into the ordinary, editable reps control.
- The manually confirmed rep value always remains the only authoritative logged count. No raw accelerometer/gyroscope samples are stored, synced, or sent to IsAIah.
- Motion capture is stopped when a set is saved, canceled, or the workout is ended/undone.
- Separate Watch haptic settings control start-of-set confirmation and rest-completion notifications.

## Physical-device QA
- [ ] Check Apple Watch native target compiles, app launches, and strength workout works as before.
- [ ] Turn on motion rep estimate in Watch Settings; start a set and confirm `Learning this movement` appears during sampling.
- [ ] Perform 8–12 controlled repetitions for a wrist-moving exercise (e.g., dumbbell curls); compare estimated reps with visually counted reps. **No accuracy guarantee until calibrated.**
- [ ] Try an exercise with little visible wrist motion; verify no invented reliable reading is implied.
- [ ] Verify changing manual reps with + / – never automatically changes when motion estimate rises.
- [ ] Tap Use Estimate; confirm it only updates editable reps and requires explicit NEXT · SAVE SET to log.
- [ ] Save the set; confirm estimated count stops and does not leak into the next set.
- [ ] Switch set, undo workout, and pause/rest; confirm capture stops when no working set is active.
- [ ] Disable motion assist mid-set; confirm the detector stops.
- [ ] Enable Watch haptics and separately verify start tap, rest-complete prominent haptic, manual and auto next-set modes.
- [ ] Optional: enable background rest notification permission; verify it is canceled after skip, pause, and undo.
- [ ] Verify no motion payload is included in WatchConnectivity or cloud synchronization.
- [ ] Observe battery/CPU impact while lifting; adjust 25-Hz sampling down as needed.
- [ ] Test older Watch model / unavailable motion source; manual workout continues without interruption.

## Limitations
- Wrist motion is not equivalent to the movement of a barbell, knee, or torso. Bench press, squats, carries, static holds, and many cable exercises can be missed or overcounted.
- Full-direction simple heuristic is a prototype, not a trained, exercise-specific model. Exercise selection, calibration, per-rep confidence, and longitudinal tempo analysis will require physical-device samples and validation.
- WHOOP's public developer API is for processed workouts/recovery, not a documented raw, live gyro/accel sensor stream. The first motion estimator uses the Apple Watch only.
