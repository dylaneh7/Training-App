import Foundation

func movement(_ name: String, lo: Int = 8, hi: Int = 12) -> HCExercise {
    HCExercise(id:"test",name:name,originalName:name,
        exerciseIndex:0,prescribedSets:3,repMin:lo,repMax:hi,
        suggestedWeightLb:nil,restSeconds:120)
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError("Progression test failed: \(message)")
    }
}

let barbell = HCPerformanceSet(exercise:"Flat barbell bench press",
                               weightLb:155,reps:7,rir:2,date:"2026-11-01")
let dumbbell = movement("Flat dumbbell bench press",lo:8,hi:12)
let estimate = HCProgressionEngine.suggest(dumbbell,history:[barbell])
check(estimate.perDumbbell,"Dumbbell target must say weight per dumbbell")
check(estimate.confidence.contains("Low"),"Cross-equipment prediction must show low confidence")
check((estimate.weightLb ?? 0) >= 35 && (estimate.weightLb ?? 999) <= 65,
      "155 x 7 barbell must not be copied directly to a single dumbbell")
print("Barbell 155 x 7 => flat DB start ~\(estimate.weightLb ?? 0) lb PER dumbbell (\(estimate.confidence))")

let actualDB = HCPerformanceSet(exercise:"Flat dumbbell bench press",
                                weightLb:55,reps:9,rir:2,date:"2026-11-08")
let learned = HCProgressionEngine.suggest(dumbbell,history:[barbell,actualDB])
check(learned.confidence == "High",
      "Actual dumbbell performance must override any generic barbell conversion")
check(learned.weightLb != nil,"Actual dumbbell set must yield a direct suggestion")
print("After an actual DB set, confidence: \(learned.confidence)")

let ready = HCPerformanceSet(exercise:"Flat barbell bench press",
                             weightLb:155,reps:8,rir:2,date:"2026-11-08")
let next = HCProgressionEngine.suggest(movement("Flat barbell bench press",lo:6,hi:8),
                                       history:[ready],aggressive:true)
check((next.weightLb ?? 0) >= 160,"Earned weight progression should increase by a real increment")
print("After 155 x 8 with 2 RIR => \(next.weightLb ?? 0) lb")

let unrelated=HCProgressionEngine.suggest(movement("Romanian deadlift"),history:[barbell])
check(unrelated.weightLb == nil,"Do not invent weights from unrelated exercises")
let returnSuggestion=HCProgressionEngine.suggest(movement("Flat barbell bench press"),
                                                  history:[ready],returning:true)
check((returnSuggestion.weightLb ?? 999) < ready.weightLb,
      "Return-from-break recommendation must not force an increase")
print("All evidence-aware progression smoke tests passed.")

// The iPhone is the only authority for what was planned on a given date.
// A successful empty snapshot is a real rest day, not a stale workout.
let sundayRest = HCWatchSchedule(date: "2026-11-15", workout: nil, runPlan: nil,
                                 generatedAt: Date(timeIntervalSince1970: 1_763_200_000),
                                 state: "ready")
let decodedRest = try JSONDecoder().decode(HCWatchSchedule.self,
                                           from: JSONEncoder().encode(sundayRest))
check(decodedRest.workout == nil && decodedRest.runPlan == nil,
      "Rest days must round-trip as explicitly empty plans")
check(decodedRest.date == "2026-11-15" && decodedRest.state == "ready",
      "Rest day snapshot date and authority must be preserved")
let sampleSaturday = HCWorkout.preview
check(sampleSaturday.date == "2026-11-14", "Saturday preview remains Saturday only")
let unscheduled = HCWorkout.unscheduled(date: "2026-11-15")
check(unscheduled.date == "2026-11-15" && unscheduled.exercises.isEmpty && !unscheduled.isPreview,
      "Watch must use an empty, dated rest-day placeholder in production")
let saturdaySnapshot = HCWatchSchedule(date: "2026-11-14", workout: sampleSaturday,
                                       runPlan: nil, generatedAt: Date(), state: "ready")
check(saturdaySnapshot.date != decodedRest.date,
      "Yesterday's snapshot must not be treated as today's plan")
print("Dated schedule and rest-day serialization tests passed.")


// EITAN wearable attribution regression checks. These run in the same Swift
// smoke-test binary as the existing workout progression tests; no HealthKit
// permissions are needed to verify strict provider provenance.
check(HCEitanWearableSource.accepts("WHOOP", preferred: "WHOOP"),
      "WHOOP data should be accepted when WHOOP is primary")
check(HCEitanWearableSource.accepts("WHOOP Inc.", preferred: "WHOOP"),
      "WHOOP app source variations should match")
check(!HCEitanWearableSource.accepts("Dylan's Apple Watch", preferred: "WHOOP"),
      "WHOOP primary must not silently use Apple Watch heart or HRV readings")
check(!HCEitanWearableSource.accepts("Garmin via Tredict", preferred: "WHOOP"),
      "Historical Garmin via Tredict must not be WHOOP recovery")
check(!HCEitanWearableSource.accepts("Tredict Personal API", preferred: "Auto"),
      "Tredict historical recovery must not be used as current wearable physiology")
check(HCEitanWearableSource.accepts("Apple Watch", preferred: "Apple Watch"),
      "Apple Watch users must retain their own measurements")
check(!HCEitanWearableSource.accepts("WHOOP", preferred: "Apple Watch"),
      "Apple Watch preference must exclude WHOOP physiology")
check(HCEitanWearableSource.accepts("Garmin Connect", preferred: "Garmin"),
      "Garmin primary should use actual Garmin Health source measurements")
check(!HCEitanWearableSource.accepts("Garmin via Tredict", preferred: "Garmin"),
      "Garmin primary must not use Tredict's archived recovery as a fresh feed")
check(HCEitanWearableSource.accepts("WHOOP", preferred: "Auto"),
      "Automatic mode should accept current WHOOP HealthKit data")

var whoopScore = HCEitanSnapshot(
    date: "2026-11-17", value: 74, factors: [], status: "Challenge",
    coaching: "Controlled challenge", consecutiveLowDays: 0,
    sourceCount: 1, coverage: "WHOOP primary")
whoopScore.primaryWearable = "WHOOP"
let encodedEitan = try JSONEncoder().encode(whoopScore)
let decodedEitan = try JSONDecoder().decode(HCEitanSnapshot.self,
                                            from: encodedEitan)
check(decodedEitan.primaryWearable == "WHOOP" && decodedEitan.value == 74,
      "Watch EITAN snapshot must preserve primary wearable and wellness score")
print("EITAN primary wearable source and Watch snapshot regression tests passed.")


// Build 47 EITAN transport diagnostics: "received but baseline missing" and
// "no packet" are different states. The serialization must preserve that
// distinction across the iPhone/Watch boundary.
var insufficient = HCEitanSnapshot(
    date: "2026-11-17", value: nil, factors: [],
    status: "Building your personal baseline",
    coaching: "More readings required", consecutiveLowDays: 0,
    sourceCount: 0, coverage: "WHOOP source · insufficient baseline")
insufficient.primaryWearable = "WHOOP"
let encodedInsufficient = try JSONEncoder().encode(insufficient)
let decodedInsufficient = try JSONDecoder().decode(
    HCEitanSnapshot.self, from: encodedInsufficient)
check(decodedInsufficient.value == nil,
      "No physiological baseline must remain nil on Watch, not zero")
check(decodedInsufficient.primaryWearable == "WHOOP",
      "A missing score must retain primary wearable provenance")
check(HCPayload.eitanStamp != HCPayload.schedule &&
      HCPayload.eitanSnapshot != HCPayload.schedule,
      "EITAN snapshot and schedule must keep separate dictionary keys")
print("EITAN nil-baseline, source attribution and packet-key regression checks passed.")


// Build 50: the durable cloud record and fast WatchConnectivity update hint
// must remain distinct from workout event / undo payload families.
check(HCPayload.progressCloudChanged == "imunCloudProgressChangedV1",
      "iPhone and Watch share the exact cloud-progress notification kind")
check(HCPayload.progressCloudChanged != HCPayload.loggedSet &&
      HCPayload.progressCloudChanged != HCPayload.workoutUndo &&
      HCPayload.progressCloudChanged != HCPayload.pushSchedule,
      "A cloud refresh hint must not be interpreted as a new workout event")

// The client compares Hashable cloud records before publishing a UI change;
// corrections to weight/reps for the same UUID must still register as a change.
let comparisonID = UUID()
let oldSet = HCLoggedSet(
    id: comparisonID, workoutID: "w", workoutDate: "2026-11-17",
    sessionKey: "s", workoutTitle: "Session", exerciseID: "e",
    exerciseName: "Squat", exerciseIndex: 0, index: 1,
    weightLb: 135, reps: 6, rir: 2, completedAt: Date(timeIntervalSince1970: 50))
let correctedSet = HCLoggedSet(
    id: comparisonID, workoutID: "w", workoutDate: "2026-11-17",
    sessionKey: "s", workoutTitle: "Session", exerciseID: "e",
    exerciseName: "Squat", exerciseIndex: 0, index: 1,
    weightLb: 145, reps: 6, rir: 2, completedAt: Date(timeIntervalSince1970: 50))
check(Set([oldSet]) != Set([correctedSet]),
      "Same-UUID set correction must refresh the other device")
check(Set([oldSet]) == Set([oldSet]),
      "Identical cloud sets must not force an unnecessary UI refresh")
print("Build 50 cloud-progress signaling and change-detection checks passed.")


// Build 62: an isolated arm is a separate prescribed set slot, not an extra
// duplicate of a bilateral set. No HealthKit or Watch hardware is needed.
var singleArm = HCExercise(
    id:"single-arm-row", name:"One-arm dumbbell row",
    originalName:"One-arm dumbbell row", exerciseIndex:0,
    prescribedSets:6, repMin:8, repMax:12,
    suggestedWeightLb:50, restSeconds:90)
check(singleArm.isUnilateral,"One-arm rows must be recognized as unilateral")
check(singleArm.side(forSet:1) == .left &&
      singleArm.side(forSet:2) == .right &&
      singleArm.side(forSet:5) == .left &&
      singleArm.side(forSet:6) == .right,
      "Six unilateral sets must alternate three left and three right")
check(singleArm.setSummary.contains("3 per side"),
      "Workout UI must show that six total sets means three per side")
let sideCount = (1...singleArm.prescribedSets).reduce(into:[HCWorkingSide:Int]()) {
    counts, slot in
    if let side = singleArm.side(forSet:slot) {
        counts[side,default:0] += 1
    }
}
check(sideCount[.left] == 3 && sideCount[.right] == 3,
      "No side can accidentally receive six prescribed sets")
var cableRaise = movement("Cable lateral raise")
check(!cableRaise.isUnilateral,
      "An ambiguous bilateral name must not be forced one-sided")
cableRaise.movementType = "unilateral"
check(cableRaise.isUnilateral,"The exercise editor must be able to mark ambiguous cable moves unilateral")
let ordinaryBench = movement("Flat dumbbell bench press")
check(!ordinaryBench.isUnilateral && ordinaryBench.side(forSet: 1) == nil,
      "Simultaneous dumbbell bench is bilateral even with a sensor on each wrist")

// Old sets without a side or motion payload must still load after updating.
let legacyBytes = try JSONEncoder().encode(oldSet)
let legacyDecoded = try JSONDecoder().decode(HCLoggedSet.self,from:legacyBytes)
check(legacyDecoded.side == nil && legacyDecoded.motionInsight == nil,
      "Legacy recorded sets must not require new optional motion fields")
var sideSet = oldSet
sideSet.side = .left
sideSet.motionInsight = HCMotionSetInsight(
    wearSide:"left",detectedReps:6,averageCycleSeconds:1.7,
    lastCycleSeconds:2.1,lastCycleSlowdownPercent:23.5,
    lastWristMotionIntensityChangePercent:-15,
    note:"Last cycle was slower; wrist-motion proxy only")
let restored = try JSONDecoder().decode(HCLoggedSet.self,
                   from:JSONEncoder().encode(sideSet))
check(restored.side == .left &&
      restored.motionInsight?.detectedReps == 6 &&
      restored.motionInsight?.wearSide == "left",
      "Motion summaries must retain their physical side and source")
print("Build 62 unilateral slots, backward decoding and motion summary tests passed.")


// Build 62 cloud round-trip: side provenance and compact movement metrics
// must survive when a Watch uploads while the iPhone is disconnected.
let cloudWorkout = HCWorkout(
    id: "2026-11-18-test", date: "2026-11-18", sessionKey: "test",
    title: "Source-aware training", exercises: [singleArm], isPreview: false)
let insightBytes = try JSONEncoder().encode(sideSet.motionInsight!)
let insightObject = try JSONSerialization.jsonObject(with: insightBytes)
let cloudRow: [String: Any] = [
    "id": UUID().uuidString.lowercased(),
    "workout_date": "2026-11-18",
    "session_key": "test",
    "workout_title": "Source-aware training",
    "exercise_id": "single-arm-row",
    "exercise_name": "One-arm dumbbell row",
    "exercise_index": 0,
    "set_index": 1,
    "reps": 6,
    "completed_at": "2026-11-18T06:00:00.000Z",
    "source": "Apple Watch",
    "working_side": "left",
    "motion_insight": insightObject
]
let recoveredCloud = HCSetReconciliation.decodeCloudRows(
    [cloudRow], workout: cloudWorkout)
check(recoveredCloud.count == 1 &&
      recoveredCloud[0].side == .left &&
      recoveredCloud[0].motionInsight?.wearSide == "left" &&
      recoveredCloud[0].motionInsight?.detectedReps == 6,
      "Cloud restores working side and labeled per-set motion summary")
var oldCloudRow = cloudRow
oldCloudRow.removeValue(forKey:"working_side")
oldCloudRow.removeValue(forKey:"motion_insight")
let inferred = HCSetReconciliation.decodeCloudRows(
    [oldCloudRow], workout: cloudWorkout)
check(inferred.count == 1 && inferred[0].side == .left &&
      inferred[0].motionInsight == nil,
      "Legacy cloud rows infer side without inventing movement data")
print("Build 62 cloud side and motion summary decoding tests passed.")
