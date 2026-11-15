import Foundation

// MARK: - Data shared by the iPhone and the watch

struct HCExercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let originalName: String
    let exerciseIndex: Int
    let prescribedSets: Int
    let repMin: Int
    let repMax: Int
    let suggestedWeightLb: Double?
    let restSeconds: Int
    var instructions: String? = nil

    var repDescription: String { "\(repMin)–\(repMax)" }
}

struct HCWorkout: Codable, Identifiable {
    let id: String
    let date: String                 // Local calendar YYYY-MM-DD
    let sessionKey: String           // Health Coach session key, e.g. 2-SatUpper
    let title: String
    let exercises: [HCExercise]
    let isPreview: Bool

    var prescribedSetCount: Int { exercises.reduce(0) { $0 + $1.prescribedSets } }

    static let preview = HCProgramCatalog.makeWorkout(date: "2026-11-14",
                                                     sessionKey: "2-SatUpper",
                                                     title: "Full Upper — Return to Training",
                                                     savedHistory: [:],
                                                     isPreview: true)
}

struct HCLoggedSet: Codable, Identifiable, Hashable {
    let id: UUID
    let workoutID: String
    let workoutDate: String
    let sessionKey: String
    let workoutTitle: String
    let exerciseID: String
    let exerciseName: String
    let exerciseIndex: Int
    let index: Int
    let weightLb: Double?
    let reps: Int
    let rir: Double?
    let completedAt: Date
    var startedAt: Date? = nil
    var durationSeconds: Double? = nil
    var source: String? = nil
}

/// A run from the Command Center calendar. Runs are separate from lifting
/// sessions so one can't accidentally mark the other as completed.
struct HCRunPlan: Codable, Identifiable, Hashable {
    let id: String
    let date: String
    let title: String
    let notes: String
    let targetDistanceMiles: Double?
    let isCompleted: Bool
}

struct HCRunFinished: Codable, Identifiable, Hashable {
    let id: UUID
    let planID: String?
    let date: String
    let startedAt: Date
    let endedAt: Date
    let distanceMeters: Double?
    let averageHeartRate: Double?
    var splits: [HCRunSplit] = []
}

struct HCRunSplit: Codable, Hashable, Identifiable {
    let index: Int
    let elapsedSeconds: Double
    let distanceMeters: Double?
    var id: Int { index }
}

/// A saved run from HealthKit, the watch, or an authorized existing provider.
/// Optional fields reflect what that source actually shared: never invent metrics.
/// Planner items sourced from Command Center, including changes made in IMUN.
struct HCPlannedSession: Codable, Identifiable, Hashable {
    let id: String
    let date: String
    let title: String
    let kind: String
    let notes: String
    let completed: Bool
    let originalDate: String?
}

struct HCTrainingActivity: Codable, Identifiable {
    let id: String
    let date: String
    let title: String
    let kind: String
    let source: String
    let distanceMeters: Double?
    let durationSeconds: Double?
    let averageBPM: Double?
    let maxBPM: Double?
    let calories: Double?
    let perceivedEffort: Double?
    var totalDurationSeconds: Double? = nil
    var paceSecondsPerKm: Double? = nil
    var enjoyment: Double? = nil
    var attribution: String? = nil
    var externalID: String? = nil
    // Source-attributed extended metrics, populated only when recorded.
    var powerWatts: Double? = nil
    var cadenceSPM: Double? = nil
    var ascentMeters: Double? = nil
    var strengthSetCount: Int? = nil
    var strengthRepetitions: Int? = nil
    var tonnageKilograms: Double? = nil
    var maxSetWeightKilograms: Double? = nil
    var activeSetSeconds: Double? = nil
    var restSeconds: Double? = nil
    var runningEffectiveness: Double? = nil
    var vo2Max: Double? = nil
}

struct HCProgressRun: Codable, Identifiable {
    let id: String
    let date: String
    let title: String
    let source: String
    let distanceMeters: Double?
    let durationSeconds: Double?
    var averageBPM: Double?
    let splits: [HCRunSplit]
    var startedAt: Date? = nil
    var endedAt: Date? = nil
    var maxBPM: Double? = nil
    var activeCalories: Double? = nil
    var averagePowerWatts: Double? = nil
    var averageCadenceSPM: Double? = nil
    var elevationGainMeters: Double? = nil
    var sourceBundleID: String? = nil
    var fromAppleHealth: Bool = false
    // On-device detail data from the same attributed HealthKit source.
    // These are not uploaded to a remote server.
    var heartRateTrace: [HCRunHeartPoint] = []
    var routePoints: [HCRunRoutePoint] = []
}

struct HCRunHeartPoint: Codable, Hashable, Identifiable {
    let at: Date
    let bpm: Double
    var id: Date { at }
}

struct HCRunRoutePoint: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double?
}

struct HCRecoveryDatum: Codable, Identifiable {
    let date: String
    let sleepSeconds: Double?
    let hrvMS: Double?
    let hrvBaselineMS: Double?
    let dailyLowHR: Double?
    let source: String
    // Different devices and services may each record a value on the same day.
    // Keep provenance separate instead of silently dropping the second source.
    var id: String { date + ":" + source }
}

enum HCPayload {
    static let workout = "workout"
    static let runPlan = "runPlan"
    static let runHistory = "runHistory"
    static let accentStyle = "hcAccentStyle"
    static let weightIncrement = "hcWeightIncrement"
    static let restOverride = "hcRestOverrideSeconds"
    static let watchHaptics = "hcWatchHaptics"
    static let completedRun = "completedRun"
    static let loggedSet = "loggedSet"
    static let kind = "kind"
    static let data = "payload"
}
