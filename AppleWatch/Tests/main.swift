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
check(HCExercise.isOneSidedName("Flat bench dumbell row"),
      "Athlete's common spelling of one-arm row must still produce left/right slots")
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


// Build 63: the complete offline exercise catalog, form cues and intelligent
// swaps must remain usable without any remote API.
check(HCExerciseLibrary.all.count >= 800,
      "iMun exercise library should include the expanded offline catalog")
check(HCExerciseLibrary.all.allSatisfy { !$0.name.isEmpty &&
      !$0.instructions.isEmpty },
      "Every browseable exercise must provide how-to instructions")
check(HCExerciseLibrary.all.contains {
    $0.source.contains("Free Exercise DB") && !$0.formTip.isEmpty &&
    !$0.primaryMuscles.isEmpty
}, "Imported exercise records must include muscles and form tips")
let rowChoices = HCExerciseLibrary.alternatives(for: singleArm, limit: 10)
check(!rowChoices.isEmpty,
      "Smart Swap should find muscle-matched alternatives for a one-arm row")
check(rowChoices.allSatisfy {
    $0.kind == "strength" &&
    HCProgramCatalog.normalized($0.name) !=
        HCProgramCatalog.normalized(singleArm.name)
}, "Smart Swap must not use unrelated cardio/stretches in a lifting plan")
let chestBench = movement("Flat barbell bench press")
check(!HCExerciseLibrary.alternatives(for: chestBench, limit: 5).isEmpty,
      "Horizontal press movements should have appropriate substitutions")
print("Build 63 offline catalog, instructions and smart swap tests passed: \(HCExerciseLibrary.all.count) unique movements.")


// Build 64: device placement is explicit per vendor, independent of whether
// live IMU access is supported, with correct migration and side attribution.
let placementDefaults = UserDefaults(suiteName: "imun-wearable-qa-\(UUID())")!
placementDefaults.set("left", forKey: "hcWatchWearSide")
placementDefaults.set("right", forKey: "hcWhoopWearSide")
IMUNWearablePlacementStore.migrateLegacy(defaults: placementDefaults)
check(IMUNWearablePlacementStore.location("appleWatch", defaults:placementDefaults) == .leftWrist,
      "Old left-wrist setting must migrate without user action")
check(IMUNWearablePlacementStore.location("whoop", defaults:placementDefaults) == .rightWrist,
      "Old WHOOP right-wrist setting must migrate")
check(IMUNWearableLocation.leftUpperArm.side == .left &&
      IMUNWearableLocation.rightForearm.side == .right,
      "Upper-arm/biceps and forearm placement must retain physical side")
check(IMUNWearableLocation.other.side == nil &&
      IMUNWearableLocation.notWorn.side == nil,
      "Unassigned and non-arm positions must not fabricate unilateral side attribution")
IMUNWearablePlacementStore.save(.rightUpperArm,for:"appleWatch",defaults:placementDefaults)
IMUNWearablePlacementStore.save(.leftForearm,for:"whoop",defaults:placementDefaults)
let placementPacket = IMUNWearablePlacementStore.payload(defaults:placementDefaults)
check(placementPacket["appleWatch"] == "rightUpperArm" &&
      placementPacket["whoop"] == "leftForearm",
      "Device-specific placements must survive WatchConnectivity transfer")
let watchDefaults = UserDefaults(suiteName: "imun-watch-qa-\(UUID())")!
check(IMUNWearablePlacementStore.apply(placementPacket, defaults:watchDefaults),
      "New position packet should be recognized")
check(IMUNWearablePlacementStore.location("appleWatch", defaults:watchDefaults) == .rightUpperArm,
      "Watch must restore upper-arm position without reducing it to right wrist")
check(IMUNWearablePlacementStore.location("whoop", defaults:watchDefaults) == .leftForearm,
      "Watch must restore future WHOOP forearm position")
check(!IMUNWearableCatalog.devices.first(where:{$0.id == "whoop"})!.hasSupportedLiveMotion,
      "WHOOP must never falsely advertise raw real-time IMU access")
let invalidPacket = ["appleWatch":"wrongSide","futureDevice":"leftWrist"]
check(!IMUNWearablePlacementStore.apply(invalidPacket, defaults: watchDefaults),
      "Unknown device IDs and invalid body locations must not change settings")
check(IMUNWearablePlacementStore.location("appleWatch", defaults:watchDefaults) == .rightUpperArm,
      "Invalid sync must not erase an existing choice")

// Sample quality and location are persisted with the original set UUID.
var qualitySet = sideSet
qualitySet.motionInsight?.wearableLocation = IMUNWearableLocation.leftUpperArm.rawValue
qualitySet.motionInsight?.motionModelVersion = 2
qualitySet.motionInsight?.motionSampleCount = 235
qualitySet.motionInsight?.sampleCoveragePercent = 96.7
qualitySet.motionInsight?.samplingGapCount = 0
qualitySet.motionInsight?.analysisConfidence = "Moderate"
let qualityRoundTrip = try JSONDecoder().decode(HCLoggedSet.self,
                      from: JSONEncoder().encode(qualitySet))
check(qualityRoundTrip.motionInsight?.wearableLocation == "leftUpperArm" &&
      qualityRoundTrip.motionInsight?.motionSampleCount == 235,
      "Saved workout analysis must preserve placement and signal provenance")

// Cloud history can decode past days without today's workout plan.
let historyDecoded = HCSetReconciliation.decodeMotionHistoryRows([cloudRow])
check(historyDecoded.count == 1 &&
      historyDecoded[0].motionInsight?.detectedReps == 6,
      "Historic cloud motion decoding must retain movement observations")

// Repeated same-exercise/placement sessions support a cautious forecast,
// while mixed forearm/biceps/wrist data must never be joined.
var sampleSessions: [HCLoggedSet] = []
for i in 0..<5 {
    var entry = HCLoggedSet(
        id: UUID(), workoutID:"forecast-\(i)",
        workoutDate:String(format:"2026-11-%02d",i+1),
        sessionKey:"forecast-\(i)", workoutTitle:"Workout \(i)",
        exerciseID:"single-arm-row", exerciseName:"One-arm dumbbell row",
        exerciseIndex:0,index:1,weightLb:50+Double(i),
        reps:8,rir:2,
        completedAt:Date(timeIntervalSince1970:Double(i)*86_400))
    entry.side = .left
    entry.motionInsight = HCMotionSetInsight(
        wearSide:"left",detectedReps:8,
        averageCycleSeconds:1.9-Double(i)*0.025,
        lastCycleSeconds:2.0,
        lastCycleSlowdownPercent:8,
        lastWristMotionIntensityChangePercent:-3,
        note:"Experimental wrist movement")
    entry.motionInsight?.wearableLocation = "leftWrist"
    entry.motionInsight?.analysisConfidence = "Moderate"
    entry.motionInsight?.sampleCoveragePercent = 96
    entry.motionInsight?.samplingGapCount = 0
    sampleSessions.append(entry)
}
let motionProjection = IMUNMotionAnalytics.forecastMotion(
    sampleSessions,exerciseName:"One-arm dumbbell row",location:"leftWrist")
check(motionProjection != nil && motionProjection!.sessionCount == 5 &&
      motionProjection!.projectedNextCycleSeconds > 0,
      "Five comparable movement sessions should yield a bounded trend projection")
check(IMUNMotionAnalytics.forecastMotion(
    sampleSessions,exerciseName:"One-arm dumbbell row",
    location:"leftUpperArm") == nil,
    "Motion projections must not combine wrist and biceps recordings")
check(IMUNMotionAnalytics.forecastStrength(sampleSessions,
    exerciseName:"One-arm dumbbell row")?.sessionCount == 5,
    "Logged load and reps should support a separately labeled e1RM trend")
var lowQuality = sampleSessions
for i in lowQuality.indices {
    lowQuality[i].motionInsight?.sampleCoveragePercent = 40
}
check(IMUNMotionAnalytics.forecastMotion(lowQuality,
    exerciseName:"One-arm dumbbell row",location:"leftWrist") == nil,
    "Low-quality sensor sessions must not produce confident predictions")
print("Build 64 device placement, historical motion, capture quality and guarded forecasts passed.")


// Selah Stone Running Lab — deterministic source/measurement regression tests.
// This test suite uses no Apple Health permissions and no fabricated GPS route.
var testRun = HCProgressRun(
    id: "healthkit:test-run", date: "2026-11-20",
    title: "Morning Run", source: "Apple Watch",
    distanceMeters: 5000, durationSeconds: 1500,
    averageBPM: 143, splits: [])
testRun.startedAt = Date(timeIntervalSince1970: 1795147200)
testRun.endedAt = testRun.startedAt!.addingTimeInterval(1500)
testRun.sensorSeries = [
    HCRunSensorReading(kind: "runningPower",
        at: testRun.startedAt!, value: 280),
    HCRunSensorReading(kind: "runningStrideLength",
        at: testRun.startedAt!, value: 1.12)
]
testRun.averageStrideLengthMeters = 1.12

let encodedRunning = try JSONEncoder().encode(testRun)
let restoredRunning = try JSONDecoder().decode(
    HCProgressRun.self, from: encodedRunning)
check(restoredRunning.sensorSeries?.count == 2 &&
      restoredRunning.averageStrideLengthMeters == 1.12,
      "Source-observed running dynamics must persist in the on-device archive")

// An older persisted run omits all Running Lab keys but retains the existing
// original model shape; new optional fields must never break its decoding.
var oldObject = try JSONSerialization.jsonObject(with: encodedRunning) as! [String: Any]
for key in ["sensorSeries", "averageStrideLengthMeters",
            "averageGroundContactTimeMS", "averageVerticalOscillationCM",
            "averageRunningSpeedMPS", "routeMileSplits"] {
    oldObject.removeValue(forKey: key)
}
let oldJSON = try JSONSerialization.data(withJSONObject: oldObject)
let oldRunRestored = try JSONDecoder().decode(HCProgressRun.self, from: oldJSON)
check(oldRunRestored.sensorSeries == nil &&
      oldRunRestored.averageStrideLengthMeters == nil,
      "Legacy runs cannot lose their history when Running Lab is introduced")

var importedDuplicate = testRun
importedDuplicate = HCProgressRun(
    id: "tredict:test-run", date: testRun.date,
    title: "Same run from Garmin", source: "Garmin via Tredict",
    distanceMeters: 5010, durationSeconds: 1504,
    averageBPM: 144, splits: [])
importedDuplicate.startedAt = testRun.startedAt
let uniqueRunning = IMUNRunningIntelligence.uniqueRuns(
    [testRun, importedDuplicate])
check(uniqueRunning.count == 1,
      "Duplicate Apple Health and Garmin publishes must not double-count mileage")
let loadRunning = IMUNRunningIntelligence.weeklyLoad(
    [testRun, importedDuplicate],
    now: Date(timeIntervalSince1970: 1795200000))
check(loadRunning.distinctRuns7 == 1 &&
      loadRunning.recent7Miles > 3 && loadRunning.recent7Miles < 3.2,
      "A single 5K recorded twice remains one run in weekly mileage")

let bestRunning = IMUNRunningIntelligence.bestEfforts([testRun])
check(bestRunning.count == 1 &&
      bestRunning.first?.distanceName == "5K",
      "Whole recorded runs match only actual benchmark-distance efforts")
check(IMUNRunningIntelligence.formatPace(
    IMUNRunningIntelligence.pacePerMile(testRun)) == "8:03",
    "5,000 meters in 25 minutes should be 8:03 per mile")

testRun.heartRateTrace = [
    HCRunHeartPoint(at: testRun.startedAt!, bpm: 100),
    HCRunHeartPoint(at: testRun.startedAt!.addingTimeInterval(30), bpm: 117),
    HCRunHeartPoint(at: testRun.startedAt!.addingTimeInterval(60), bpm: 140),
    HCRunHeartPoint(at: testRun.startedAt!.addingTimeInterval(90), bpm: 165),
    HCRunHeartPoint(at: testRun.startedAt!.addingTimeInterval(120), bpm: 173)
]
check(IMUNRunningIntelligence.heartRateZones(testRun, maxBPM: 0).isEmpty,
      "Heart-rate zones are never estimated from age or a missing maximum")
let zones = IMUNRunningIntelligence.heartRateZones(testRun, maxBPM: 180)
check(zones.count == 5 &&
      abs(zones.reduce(0.0) { $0 + $1.seconds } - 120) < 0.01,
      "Heart-rate zones use actual sample intervals, not invented minutes")
print("Running Lab provenance, old-cache, duplicate, best effort and zone tests passed.")
