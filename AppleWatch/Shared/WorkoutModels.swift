import Foundation
import CryptoKit

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

    static func unscheduled(date: String) -> HCWorkout {
        HCWorkout(id: "rest-" + date, date: date, sessionKey: "none-" + date,
                  title: "No strength workout scheduled", exercises: [], isPreview: false)
    }

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

/// A running step that can be displayed on both iPhone and iMun Watch.
/// Time/distance and BPM values only come from an actual prescribed workout.
struct HCRunStep: Codable, Hashable {
    let title: String
    let phase: String
    let seconds: Double?
    let distanceMeters: Double?
    let minBPM: Int?
    let maxBPM: Int?
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
    // Optional with a default to decode previously cached iPhone/Watch plans.
    var structuredSteps: [HCRunStep]? = nil
}

extension HCRunPlan {
    /// Stable across iPhone and watchOS processes; covers the entire plan,
    /// including step times, BPM targets and completion state.
    var syncSignature: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let payload = try? encoder.encode(self) else { return "" }
        return Data(SHA256.hash(data: payload)).base64EncodedString()
    }
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


/// EITAN: on-device, observational wellness estimate. No raw HealthKit
/// samples leave the iPhone in this compact WatchConnectivity snapshot.
struct HCEitanFactor: Codable, Identifiable {
    let id: String
    let title: String
    let value: Int
    let detail: String
    let weight: Double
}

/// Brief athlete-reported response, stored on device. A day with no entry
/// remains unknown; it must never be interpreted as good recovery.
struct HCEitanDailyCheckIn: Codable, Identifiable {
    let date: String
    let energy: Int                 // 1 = depleted, 5 = strong
    let soreness: Int               // 1 = none, 5 = severe
    let stress: Int                 // 1 = low, 5 = high
    let motivation: Int             // 1 = low, 5 = high
    let painOrIllness: Bool
    var id: String { date }
}

/// Independent from the descriptive 0–100 EITAN wellness score: an athlete
/// may choose a controlled challenge on a low-sleep day without implying
/// that sleep loss is beneficial or that next-day recovery is guaranteed.
struct HCEitanCoachingPlan: Codable {
    let mode: String                // challenge | adapt | recover
    let title: String
    let message: String
    let cues: [String]
    let reasons: [String]
    let recordedTrainingStreak: Int
    let recentTrainingDays: Int
    let recentHardDays: Int
    let shortSleepNights: Int?
    let observedSleepNights: Int
    let confidence: String
    var needsConversation: Bool { mode == "recover" }
}

/// An intentionally conservative rule policy, not an injury/overtraining
/// diagnostic or a scientifically validated clinical cutoff. Training
/// progress and the athlete's own feedback remain part of the decision.
enum HCEitanCoachingPolicy {
    static func evaluate(wellness: Int?, lowDays: Int,
                         streak: Int, trainingDays: Int,
                         hardDays: Int, shortSleepNights: Int?,
                         sleepObservations: Int,
                         checkIn: HCEitanDailyCheckIn?,
                         style: String) -> HCEitanCoachingPlan {
        let poorSubjective = checkIn.map {
            ($0.energy <= 2 && $0.soreness >= 4) ||
            ($0.energy <= 2 && $0.stress >= 4)
        } ?? false
        let concerning = checkIn?.painOrIllness == true
        let persistentLow = lowDays >= 3
        let accumulatingLoad = streak >= 6 || (hardDays >= 4 && trainingDays >= 5)
        let repeatedShortSleep = (shortSleepNights ?? 0) >= 3 &&
            sleepObservations >= 4
        let multipleProblems = [persistentLow, accumulatingLoad,
                                repeatedShortSleep, poorSubjective]
            .filter { $0 }.count
        let recoveryReview = concerning ||
            (persistentLow && (accumulatingLoad || repeatedShortSleep || poorSubjective)) ||
            (accumulatingLoad && (repeatedShortSleep || poorSubjective)) ||
            (streak >= 8 && trainingDays >= 6)
        let adapt = !recoveryReview && (
            multipleProblems >= 1 && (streak >= 5 || poorSubjective ||
                                      (wellness ?? 100) < 45 && lowDays >= 2))
        let mode = recoveryReview ? "recover" : adapt ? "adapt" : "challenge"
        var reasons: [String] = []
        if streak >= 5 {
            reasons.append("\(streak) consecutive recorded training days; unlogged days cannot confirm recovery")
        }
        if hardDays >= 3 { reasons.append("\(hardDays) high-effort days in the past week") }
        if repeatedShortSleep {
            reasons.append("\(shortSleepNights ?? 0) recorded nights under seven hours in the past week")
        }
        if persistentLow { reasons.append("\(lowDays) consecutive lower EITAN wellness trends") }
        if poorSubjective { reasons.append("Your check-in reports pronounced fatigue or soreness/stress") }
        if concerning { reasons.append("Your check-in reports pain or illness") }
        if reasons.isEmpty, let checkIn, checkIn.energy >= 4,
           checkIn.soreness <= 2 {
            reasons.append("Your check-in supports a controlled challenge")
        }
        if reasons.isEmpty {
            reasons.append("No sustained recovery concern established from recorded data")
        }
        let styleName = ["driven", "balanced", "cautious"].contains(style)
            ? style : "driven"
        let title: String
        let message: String
        let cues: [String]
        if recoveryReview {
            title = "Review the recovery plan"
            message = concerning
                ? "Pain or illness deserves attention before strenuous exercise. Consider pausing the planned intensity and getting appropriate care."
                : "Several signals point to accumulating strain. IsAIah should propose an easy day, adjusted volume, or extra recovery—not automatically cancel your training."
            cues = [
                "Consider an easy session or a recovery day; sustained fatigue is a reason to review the plan",
                "Prioritize sufficient sleep and nutrition, and reassess how you feel tomorrow",
                "Discuss reducing lifting volume or easy aerobic work before resuming harder sessions"
            ]
        } else if adapt {
            title = "Train with adjustments"
            message = "Keep building, but adapt the work to today's response. Use warm-up performance and effort to choose the right challenge."
            cues = [
                "Lift with 2–3 repetitions in reserve; allow longer rests if performance drops",
                "Run by conversational effort or reduce harder intervals if breathing or pace deteriorates",
                "Check in after the session and review the next day's recovery"
            ]
        } else {
            title = styleName == "cautious" ? "Build consistently" : "Challenge with purpose"
            let oneBadNight = (shortSleepNights ?? 0) == 1 && sleepObservations >= 1
            message = oneBadNight
                ? "One shorter night is not an automatic rest command. Train according to warm-up feel and technique, then prioritize recovery without assuming tomorrow will make up for lost sleep."
                : "No sustained recovery warning is established. You can pursue the planned stimulus while adjusting to actual effort and technique."
            cues = styleName == "cautious" ? [
                "Follow the plan with consistent technique and controlled progression",
                "Use RIR or session effort to decide whether to add load",
                "Protect sleep and recovery without treating one metric as permission or prohibition"
            ] : [
                "If warm-ups feel solid, pursue the planned sets or run goal",
                "Push effort within good form; use RIR to adjust load rather than force failure",
                "Track the response and keep tomorrow's recovery in the plan"
            ]
        }
        let measured = [trainingDays > 0, sleepObservations >= 4,
                        wellness != nil, checkIn != nil].filter { $0 }.count
        let confidence = measured >= 3 ? "Moderate" :
            measured >= 2 ? "Limited" : "Low"
        return HCEitanCoachingPlan(mode: mode, title: title,
            message: message, cues: cues, reasons: reasons,
            recordedTrainingStreak: streak, recentTrainingDays: trainingDays,
            recentHardDays: hardDays, shortSleepNights: shortSleepNights,
            observedSleepNights: sleepObservations, confidence: confidence)
    }
}

struct HCEitanSnapshot: Codable {
    let date: String
    let value: Int?
    let factors: [HCEitanFactor]
    let status: String
    let coaching: String
    let consecutiveLowDays: Int
    let sourceCount: Int
    let coverage: String
    var coachingPlan: HCEitanCoachingPlan? = nil

    var isLow: Bool { (value ?? 100) < 60 }
    var needsRecoveryConversation: Bool {
        coachingPlan?.needsConversation ?? (consecutiveLowDays >= 3)
    }

    // Not a medical or injury-risk prediction. The coach must ask before
    // changing running targets, strength volume or rest prescriptions.
    static func advice(for score: Int?, streak: Int) -> String {
        guard let score else {
            return "More recent, comparable health readings are needed before EITAN can guide today's training."
        }
        if streak >= 3 && score < 60 {
            return "Several days of lower wellness trends: consider a recovery day, extra sleep, gentle mobility, or asking IsAIah to adjust your plan."
        }
        if score < 35 {
            return "Consider an easy day or rest. If lifting, reduce intensity and take 60–90 seconds longer between sets; if running, choose easy effort."
        }
        if score < 60 {
            return "Consider a lighter session: add 30–60 seconds between lifting sets or lower your running intensity. Recovery matters."
        }
        if score < 75 {
            return "Follow your plan at a comfortable effort, and adjust for fatigue or how you feel."
        }
        return "Your recent wellness trends look steady. You can follow your training plan and progress when form and effort support it."
    }
}

enum HCPayload {
    static let schedule = "scheduleSnapshotV2"
    static let requestSchedule = "requestScheduleV2"
    static let pushSchedule = "pushScheduleV3"
    static let scheduleReceipt = "scheduleReceiptV1"
    static let eitanSync = "imunEitanSnapshotV2"
    static let eitanRequest = "imunEitanRequestV2"
    static let eitanReceipt = "imunEitanReceiptV2"
    static let eitanSnapshot = "hcEitanSnapshot"
    static let eitanStamp = "hcEitanTimestamp"
    static let syncRequest = "syncRequestV3"
    static let syncReceipt = "syncReceiptV3"
    static let workout = "workout"
    static let runPlan = "runPlan"
    static let runHistory = "runHistory"
    static let accentStyle = "hcAccentStyle"
    static let weightIncrement = "hcWeightIncrement"
    static let restOverride = "hcRestOverrideSeconds"
    static let watchHaptics = "hcWatchHaptics"
    static let completedRun = "completedRun"
    static let loggedSet = "loggedSet"
    static let workoutUndo = "imunWorkoutUndoV1"
    static let liftSessionStatus = "imunLiftSessionStatusV1"
    static let workoutUndos = "imunWorkoutUndosV1"
    static let kind = "kind"
    static let data = "payload"
}


/// Informational Watch workout clock, independent of logged-set synchronization.
/// Only the Watch can declare that its session is active or finished.
struct HCWatchLiftSessionStatus: Codable {
    let workoutID: String
    let workoutDate: String
    let startedAt: Date?
    let isActive: Bool
    let reportedAt: Date
}

/// Date-scoped, atomic schedule sent by the iPhone to its Watch companion.
/// An absent workout/run is intentional, never an instruction to keep yesterday's plan.
struct HCWatchSchedule: Codable {
    let date: String
    let workout: HCWorkout?
    let runPlan: HCRunPlan?
    let generatedAt: Date
    /// "ready", "loading", or "signedOut". Only "ready" confirms a rest day.
    let state: String
}
