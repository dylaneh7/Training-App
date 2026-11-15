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
