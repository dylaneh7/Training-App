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
}

enum HCPayload {
    static let workout = "workout"
    static let loggedSet = "loggedSet"
    static let kind = "kind"
    static let data = "payload"
}
