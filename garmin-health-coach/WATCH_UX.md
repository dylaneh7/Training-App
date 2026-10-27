# Garmin Health Coach — Watch UX Requirements

Target device: Garmin Forerunner 970 (454×454 AMOLED, touch + five buttons).

## Design principle

The watch app is not a replacement for the full Hybrid Coach editor, and it should not duplicate Garmin's own Training Readiness experience. It is a fast wrist companion for today's programmed workout: checking the next exercise, logging sets, making small set-level changes, timing rest, and syncing those changes back to Hybrid Coach.

## Main navigation

### Glance
- Today's planned workout name or `Rest Day`.
- Progress, e.g. `6/18 sets`.
- Next exercise / next set.
- Tap/START opens the full app.

### Home
1. Today's Workout.
2. Current / next exercise.
3. Workout progress.
4. Sync status.

Garmin wellness metrics such as Body Battery or stress are optional secondary context only and should never dominate the screen.

Use UP/DOWN or swipe to move between sections. START/tap selects. BACK returns.

## Today's Workout

Show only the current day's planned session from Hybrid Coach / Command Center.

Each exercise row should show:
- Exercise name.
- Current set progress, e.g. `2/4`.
- Target or last logged load/reps, e.g. `185 × 8`.
- Completion state.

START/tap opens the exercise.

## Exercise screen

Show:
- Exercise name.
- Set number, e.g. `SET 2 OF 4`.
- Suggested target from the progression coach when available.
- Last logged set.
- Current editable values: Weight, Reps, RIR.
- Large `COMPLETE SET` action.

After completing a set, automatically advance to the next incomplete set.

## Editable fields

### Weight
- Native Garmin picker.
- Default display in pounds.
- Normal increment: 5 lb.
- Support smaller increments for dumbbells/machines when needed.
- Start picker on the currently planned/logged value.

### Reps
- Native Garmin picker.
- 1-rep increments.
- Practical range: 1–50.

### RIR
- Quick picker/menu.
- Values: 0, 1, 2, 3, 4, 5+.
- Optional `Not entered` value.

### Completion
- One press/tap toggles a set complete.
- Completed sets show a clear check mark and remain editable.

## Button-first interaction

Forerunner 970 five-button behavior:
- UP: previous row/value.
- DOWN: next row/value.
- START/ENTER: select/edit/confirm.
- BACK: cancel/go back.
- MENU hold: context menu when useful.

Touch behavior should mirror the same actions:
- Swipe: navigate.
- Tap: select.
- Native menus/pickers for numeric edits.

The app must remain fully usable without touch.

## Context actions

Long-press MENU on an exercise/set may provide:
- Edit Weight.
- Edit Reps.
- Edit RIR.
- Mark Complete / Undo Complete.
- Skip Set.
- Skip Exercise.

Avoid free-form text entry on the watch.

## Rest timer

- Completing a set starts the programmed/default rest timer automatically.
- Show remaining rest prominently while still allowing navigation.
- Vibrate when rest ends.
- Allow quick +30 sec / skip timer actions.

## Sync behavior

- Cache the current workout and unsynced edits locally with `Application.Storage`.
- Weight/reps/RIR edits should save immediately on-watch.
- Sync changes back to the Hybrid Coach cloud state whenever the phone/network connection is available.
- If offline, show `Saved on watch` and retry later.
- Never discard an unsynced completed set just because the app closes.

## Scope

Do not allow full program construction, exercise-library management, complex scheduling, or long-form notes on-watch; those remain in the phone/web app.

## Later improvements

- Quick `+5 lb` / `-5 lb` actions.
- PR indicator.
- Previous-session comparison.
- Mark full workout complete from the watch.
- Optional small wellness context strip if it proves useful without clutter.
