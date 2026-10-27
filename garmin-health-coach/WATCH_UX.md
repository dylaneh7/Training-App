# Garmin Health Coach — Watch UX Requirements

Target device: Garmin Forerunner 970 (454×454 AMOLED, touch + five buttons).

## Design principle

The watch app is not a replacement for the full Hybrid Coach editor. It is a fast wrist companion for checking readiness, seeing today's plan, logging sets, and making small set-level changes during training.

## Main navigation

### Glance
- Readiness number and READY / STEADY / EASY / RECOVER label.
- Today's planned workout status.
- Tap/START opens the full app.

### Home
1. Readiness summary.
2. Today's Workout card.
3. Recovery metrics.
4. Sync status.

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

## Sync behavior

- Cache the current workout and unsynced edits locally with `Application.Storage`.
- Weight/reps/RIR edits should save immediately on-watch.
- Sync changes back to the Hybrid Coach cloud state whenever the phone/network connection is available.
- If offline, show `Saved on watch` and retry later.
- Never discard an unsynced completed set just because the app closes.

## Safety and scope

- Readiness is a training/wellness estimate, not a medical score.
- No medication, diagnosis, or medical-record editing from the watch.
- Do not allow full program construction, exercise-library management, or complex scheduling on-watch; those remain in the phone/web app.

## Later improvements

- Rest timer after a completed set.
- Haptic alert when rest ends.
- Quick `+5 lb` / `-5 lb` actions.
- PR indicator.
- Previous-session comparison.
- Mark full workout complete from the watch.
