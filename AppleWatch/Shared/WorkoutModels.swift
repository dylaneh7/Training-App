import Foundation

/// Shared, Codable contract used by the iPhone and Apple Watch targets.
/// IDs are stable so future cloud writes can be idempotent.
struct HCExercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let prescribedSets: Int
    let repMin: Int
    let repMax: Int
    let suggestedWeightLb: Double?
    let restSeconds: Int

    var repDescription: String { "\(repMin)–\(repMax)" }
}

struct HCWorkout: Codable, Identifiable {
    let id: String
    let date: String     // Local ISO 8601 calendar date (YYYY-MM-DD)
    let title: String
    let exercises: [HCExercise]

    /// Offline example until the existing Health Coach cloud plan is connected.
    /// Sample loads are deliberately nil: the watch must never invent a weight.
    static let preview = HCWorkout(
        id: "demo-full-upper",
        date: "2026-11-14",
        title: "Full Upper — Return to Training",
        exercises: [
            .init(id: "bench", name: "Barbell Bench Press", prescribedSets: 3, repMin: 6, repMax: 8, suggestedWeightLb: nil, restSeconds: 180),
            .init(id: "pulldown", name: "Neutral-Grip Lat Pulldown", prescribedSets: 3, repMin: 8, repMax: 12, suggestedWeightLb: nil, restSeconds: 120),
            .init(id: "incline", name: "Incline Dumbbell Press", prescribedSets: 2, repMin: 8, repMax: 10, suggestedWeightLb: nil, restSeconds: 120),
            .init(id: "row", name: "Seated Row", prescribedSets: 3, repMin: 8, repMax: 12, suggestedWeightLb: nil, restSeconds: 120),
            .init(id: "shoulder", name: "Seated DB Shoulder Press", prescribedSets: 2, repMin: 8, repMax: 10, suggestedWeightLb: nil, restSeconds: 120),
            .init(id: "lateral", name: "Cable Lateral Raise", prescribedSets: 2, repMin: 12, repMax: 15, suggestedWeightLb: nil, restSeconds: 75),
            .init(id: "rear", name: "Reverse Pec Deck", prescribedSets: 2, repMin: 12, repMax: 15, suggestedWeightLb: nil, restSeconds: 75),
            .init(id: "triceps", name: "Rope Pressdown", prescribedSets: 2, repMin: 10, repMax: 15, suggestedWeightLb: nil, restSeconds: 75),
            .init(id: "biceps", name: "Hammer Curl", prescribedSets: 2, repMin: 10, repMax: 12, suggestedWeightLb: nil, restSeconds: 75)
        ]
    )
}

struct HCLoggedSet: Codable, Identifiable, Hashable {
    let id: UUID
    let workoutID: String
    let exerciseID: String
    let index: Int
    let weightLb: Double
    let reps: Int
    let completedAt: Date
}
