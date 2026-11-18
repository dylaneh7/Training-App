# Build 56 — IsAIah memory and complete exercise history

## Product intent
IsAIah can review **source-attributed workouts imported on-device** from Apple Health, iMun, Tredict/Garmin and connected training records. Past IsAIah chats are locally archived and selected athlete-authored excerpts are retrieved for relevant requests. No model fine-tuning is claimed. The model is sent bounded, question-relevant summaries, not an unbounded HealthKit database.

## Privacy and source constraints
- Apple Health workout import is on-device under HealthKit authorization.
- Workout summaries from HealthKit and current Health readings are excluded from IsAIah network context unless the user enables the explicit Health-sharing toggle and presses Send.
- Separate chat-memory switch controls reuse of past conversations. Memory is stored on the iPhone in Application Support with file protection, can be cleared under Settings, and is sent only on Send.
- Tredict/Garmin and iMun training data retain source names. Records absent from HealthKit permissions/provider sync are **not** declared present.
- No raw GPS coordinates or full heart-rate traces are sent to AI; raw Health data stays in the on-device activity history.

## QA checklist
- [ ] Fresh launch of iPhone with selected Settings tab: no missing EnvironmentObject crash.
- [ ] Run and Watch schemes compile under current Xcode; Watch pairing/sync unaffected.
- [ ] With existing Health catalog authorization, exercise importer starts without a second Health prompt.
- [ ] Import confirmed for HealthKit runs, walks, strength workouts, cycling and other available workout types.
- [ ] Historical workouts older than two years are present when HealthKit returns them.
- [ ] IsAIah can discuss source-labelled Tredict/Garmin, iMun strength sessions, run history, and Apple Health workout summaries by date and sport.
- [ ] With Apple Health sharing **off**, no HealthKit workout summaries, HealthKit run stats, or private Health readings appear in outbound assistant context.
- [ ] With sharing **on**, request includes authorized HealthKit exercise summaries and current/relevant Health metrics, after tapping Send.
- [ ] Start New conversation, close and reopen app, then ask about a prior training preference: IsAIah can retrieve relevant athlete-authored notes when chat memory is enabled.
- [ ] Disable chat memory: no older chat excerpts in outbound context; existing local archive remains until cleared.
- [ ] Clear remembered conversations in Settings; new chats cannot retrieve cleared archive.
- [ ] Source/date/year query gives relevant records without inventing missing metrics, PRs, pace or HR.
- [ ] Remote context stays bounded; no bulk HealthKit GPS upload or unexpected background AI call.
- [ ] Device test: verified Apple Health permissions, on-device history, representative older activity, and Ask IsAIah response.

## Scope limits
HealthKit workouts vary by recording source; not every activity has pace, lap, power or heart-rate data. Real-time AI context has a 24,000-character bound. For very large histories, IsAIah receives all-time counts and selected matching sessions rather than every raw record in one request.
