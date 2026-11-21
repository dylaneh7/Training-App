import Foundation

// Linux-only source-compatible fixture models. These are NOT included in
// any iPhone/Watch target and cannot replace native integration tests.
struct HCRunSplit {
    let index: Int
    let elapsedSeconds: Double
    let distanceMeters: Double?
}
struct HCRunSensorReading {
    let kind: String
    let at: Date
    let value: Double
}
struct HCRunHeartPoint {
    let at: Date
    let bpm: Double
}
struct HCRunRoutePoint {
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double?
    var recordedAt: Date? = nil
}
struct HCProgressRun {
    let id: String
    let date: String
    let title: String
    let source: String
    let distanceMeters: Double?
    let durationSeconds: Double?
    var averageBPM: Double?
    var splits: [HCRunSplit]
    var startedAt: Date? = nil
    var endedAt: Date? = nil
    var maxBPM: Double? = nil
    var activeCalories: Double? = nil
    var averagePowerWatts: Double? = nil
    var averageCadenceSPM: Double? = nil
    var elevationGainMeters: Double? = nil
    var sourceBundleID: String? = nil
    var fromAppleHealth = false
    var heartRateTrace: [HCRunHeartPoint] = []
    var routePoints: [HCRunRoutePoint] = []
    var sensorSeries: [HCRunSensorReading]? = nil
    var averageStrideLengthMeters: Double? = nil
    var averageGroundContactTimeMS: Double? = nil
    var averageVerticalOscillationCM: Double? = nil
    var averageRunningSpeedMPS: Double? = nil
    var routeMileSplits: [HCRunSplit]? = nil
    var postRunHeartRateTrace: [HCRunHeartPoint]? = nil
}

func check(_ condition: @autoclosure () -> Bool, _ reason: String) {
    guard condition() else { fatalError(reason) }
}
let start = Date(timeIntervalSince1970: 1_795_147_200)
var run = HCProgressRun(
    id: "watch-run", date: "2026-11-20", title: "5K test",
    source: "Apple Watch", distanceMeters: 5500,
    durationSeconds: 1800, averageBPM: 149, splits: [])
run.startedAt = start
run.endedAt = start.addingTimeInterval(1800)
run.averageRunningSpeedMPS = 3
run.averageCadenceSPM = 171
var points: [HCRunRoutePoint] = []
for index in 0...110 {
    points.append(HCRunRoutePoint(
        latitude: 0,
        longitude: Double(index) * (50.0 / 111_195.0),
        altitudeMeters: 35,
        recordedAt: start.addingTimeInterval(Double(index) * 1800 / 110)))
}
run.routePoints = points
let segments = IMUNRunAdvancedAnalytics.bestRouteSegments(run)
check(segments.contains(where: { $0.distanceMeters == 400 }),
      "400 m GPS best not available")
check(segments.contains(where: { $0.distanceMeters == 1000 }),
      "1 km GPS best not available")
check(IMUNRunAdvancedAnalytics.routeAssessment(run) != nil,
      "Route assessment missing")
var trace: [HCRunSensorReading] = []
for i in 0..<70 {
    let stamp = start.addingTimeInterval(Double(i * 10))
    trace.append(HCRunSensorReading(kind: "runningSpeed",
        at: stamp, value: (20...28).contains(i) ? 4.4 : 2.8))
    trace.append(HCRunSensorReading(kind: "runningPower",
        at: stamp, value: (20...28).contains(i) ? 350 : 235))
}
run.sensorSeries = trace
check(IMUNRunAdvancedAnalytics.candidateSurges(run).count == 1,
      "Source speed surge missing")
check(IMUNRunAdvancedAnalytics.powerZones(run, criticalPower: 280) != nil,
      "Power zones missing")
check(IMUNRunAdvancedAnalytics.paceZones(run,
    thresholdSecondsPerMile: 500) != nil,
    "Pace zones missing")
check(IMUNRunAdvancedAnalytics.powerZones(run, criticalPower: 0) == nil,
      "Missing threshold must not create power zones")
run.heartRateTrace = [
    HCRunHeartPoint(at: start.addingTimeInterval(1780), bpm: 171)
]
run.postRunHeartRateTrace = [
    HCRunHeartPoint(at: start.addingTimeInterval(1860), bpm: 142),
    HCRunHeartPoint(at: start.addingTimeInterval(1920), bpm: 126)
]
check(IMUNRunAdvancedAnalytics.heartRateRecovery(run).count == 2,
      "Two source-recorded HR recovery windows missing")
var copy = run
copy = HCProgressRun(id: "garmin-copy", date: run.date,
    title: "Imported Garmin", source: "Garmin", distanceMeters: 5505,
    durationSeconds: 1802, averageBPM: 150, splits: [])
copy.startedAt = start
check(IMUNRunningIntelligence.uniqueRuns([run,copy]).count == 1,
      "Identical sourced workouts must count once")
let sourceChoices = IMUNRunAdvancedAnalytics.otherSourceComparisons(
    run, history: [run,copy])
check(sourceChoices.count == 1 &&
      sourceChoices[0].detail.contains("Mean HR"),
      "Same-run Garmin and Watch evidence must remain source-comparable")
check(IMUNRunningIntelligence.uniqueRuns([run,copy])[0].routePoints.count > 50,
      "Duplicate-free mileage must keep the richer, intact source recording")
let load = IMUNRunningIntelligence.weeklyLoad(
    [run,copy], now: start.addingTimeInterval(3600))
check(load.distinctRuns7 == 1,
      "Duplicated Garmin mileage must not count as a second run")
var race = HCProgressRun(id: "race5k",date:"2026-11-20",
    title:"5K",source:"Watch",distanceMeters:5000,durationSeconds:1500,
    averageBPM:160,splits:[])
race.startedAt=start
let models=IMUNRunAdvancedAnalytics.raceForecasts([race])
check(models.contains(where:{$0.name=="10K"}) &&
      !models.contains(where:{$0.name=="Marathon"}),
      "Race-model extrapolation limits failed")
check(IMUNRunningIntelligence.formatPace(
    IMUNRunningIntelligence.pacePerMile(race)) == "8:03",
    "Whole-run pace conversion incorrect")
print("Running Lab pure-math, route, surge, zones and recovery smoke tests passed.")
