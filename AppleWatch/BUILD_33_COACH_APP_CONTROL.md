# iMun Coach — App Control Architecture (Build 33)

## Goal
Coach is iMun's natural-language operating layer, not merely a chat assistant. Any in-app operation should eventually be available to Coach **when the underlying product exposes an authenticated, validated action for it**.

The model can understand requests and propose action descriptors. Only typed native iPhone handlers are allowed to read the current app state and execute a change. The model cannot directly call SQL, overwrite HealthKit, bypass auth, change iOS settings, or invent a workout result.

## Implemented in Build 33

The active `IMUNCoachActionCatalog.available` enumerates current actions:
- **Training:** Create an editable strength workout; edit exercise prescription (add/remove/replace/reorder, sets, rep range, rest, suggested load); rename the current strength workout; create a timed run; adjust rest duration.
- **Calendar and completion:** Move a saved calendar workout; manually confirm a scheduled workout or today's run without faking sensor data.
- **Watch and running:** Resync current plan; set watch haptics, running voice cues and auto-laps.
- **App:** Switch Running/Strength, navigate main tabs, change appearance theme and motivation source.

### How execution works
1. The athlete requests a change, e.g. "Change squats to 4 sets of 8, 120 seconds rest."
2. The local parser recognizes common commands. More conversational wording can use `imun-ai-coach` POST mode `proposeAction` (server v4, signed-in JWT required). The backend returns only a JSON *proposal* from the same allowlist; no command is executed there.
3. The iPhone binds the proposal to a current workout/exercise **ID looked up on-device**, not an AI-invented ID. A review card lets the athlete correct the target and values.
4. The athlete presses **Confirm action**. The app revalidates authentication, current workout signature, numeric bounds and operation permissions.
5. For edits the app calls `PhoneWorkoutBridge.applyCoachWorkoutEdit`, which uses `saveEditedWorkout` for local persistence, cloud queue and iMun Watch. Recording edits remain separate.
6. Coach replies with an accurate result: queued locally, requested server mutation, or a specific error. It must not claim successful cloud or Watch delivery until confirmed.

### Workout edit protections
- A SHA-256 content signature rejects edits against a changed workout.
- No deletion/replacement of an exercise already having completed/active sets.
- Existing IDs and logged performance records are never silently rewritten.
- Prescribed sets 1–12, rep minimum 1–30, rep maximum up to 40, rest 15–360 seconds in 15-second increments, optional finite 0–1500 lb target.
- Exercise library and substitution entries use the app's own editable model; arbitrary code/model metadata is never executed.
- No medical advice or fabricated HealthKit, GPS, HR, pace, load or set history.

## Still to expose for broader app-wide operation

These features remain outside the current live action catalogue, **not yet controllable** via Coach. They should be added one at a time through the same registry, confirmation, execution and verification contract:
- Correct a specific historically recorded strength set (with original record ID, an audit log and undo).
- Edit a multi-interval running plan, including target BPM/time/distance; schedule Apple Workout after review.
- Add/edit custom exercise-library entries and reusable workout templates.
- Create/organize full multiday training plans and calendar recurring workouts.
- Manage Motivation Studio notes, journal entries and saved cards.
- Edit granular visual settings beyond changing the preset, including per-theme accents and component preferences.
- Open the relevant detailed HealthKit source records and adjust display preferences; changing Apple Health data requires separate platform authorization and should not happen through a generic Coach command.
- Account/data export, deletion and provider disconnect operations with separate strong confirmation and safeguards.

### Design rule for the next engineering phase
Each new operation must provide:
`id`, descriptive title, domain, needed permissions, argument schema, user confirmation level, target validation, idempotency/retry behavior, observable completion status, and whether an undo operation is possible. A raw instruction like "do anything" is **not** permission to execute arbitrary programs or irreversible actions.

## Release status
Build 33 is stacked on draft Build 32 (Health + editorial UI), which stacks on Build 31 (first Coach actions). The proven Build 30 phone/Watch companion bundle IDs and background cloud plan delivery remain intact. Server action mode v4 is deployed and independently verified as active; no installed iPhone client contains the Build 33 editing UI yet. Automated iOS/watchOS builds must pass before merging; real-device review is required.
