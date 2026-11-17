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
