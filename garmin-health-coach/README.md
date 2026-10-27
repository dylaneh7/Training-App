# Health Coach — Garmin Forerunner 970

Connect IQ watch app and glance for the Forerunner 970.

## Version 1

This first build reads wellness/training metrics directly from the watch:

- Body Battery (latest SensorHistory sample)
- Current stress
- Garmin recovery time
- Respiration rate
- Steps
- Watch battery

It creates a simple 0–100 coach readiness estimate and labels the day:

- READY
- STEADY
- EASY
- RECOVER

The estimate is for training/wellness guidance only; it is not a medical score.

## Controls

Open **Health Coach** from the app list for the full view. Add its glance to the glance loop for the quick view. Press Select/tap the main app to refresh its current data.

## Target

- Garmin Forerunner 970 (`fr970`)
- Connect IQ 6.0+
- 454×454 AMOLED layout

## Build on macOS

1. Install Visual Studio Code.
2. Install Garmin's **Monkey C** extension in VS Code.
3. Install the Connect IQ SDK Manager and download the latest SDK plus the Forerunner 970 device definition.
4. Open this `garmin-health-coach` folder in VS Code.
5. Run **Monkey C: Verify Installation**.
6. Run **Monkey C: Run Without Debugging** and choose Forerunner 970 to test in the simulator.
7. Plug the Forerunner 970 into the Mac by USB.
8. Run **Monkey C: Build for Device**, choose Forerunner 970, and copy the generated `.prg` to `GARMIN/APPS` on the watch if the extension does not sideload it automatically.

## Next version

After the watch-native MVP is verified, add cloud sync to the existing Hybrid Coach/Command Center backend so the watch can also show:

- Today's scheduled run/lift
- Completion state
- Suggested progression target
- Recent workout status
- A watch action to mark the planned workout complete
