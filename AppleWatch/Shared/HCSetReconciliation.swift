import Foundation

/// A signed-in athlete's correction to a locally recorded set or an active
/// workout window. Immutable IDs make offline retries idempotent.
struct HCWorkoutUndo: Codable, Identifiable, Hashable {
    let id: UUID
    let kind: String
    let setID: UUID?
    let workoutDate: String
    let sessionKey: String
    let startedAt: Date?
    let endedAt: Date?
    let createdAt: Date

    static func set(_ set: HCLoggedSet) -> HCWorkoutUndo {
        HCWorkoutUndo(id: UUID(), kind: "set", setID: set.id,
                      workoutDate: set.workoutDate,
                      sessionKey: set.sessionKey,
                      startedAt: nil, endedAt: nil, createdAt: Date())
    }

    static func workout(_ workout: HCWorkout, startedAt: Date,
                        endedAt: Date = Date()) -> HCWorkoutUndo {
        HCWorkoutUndo(id: UUID(), kind: "workout", setID: nil,
                      workoutDate: workout.date, sessionKey: workout.sessionKey,
                      startedAt: startedAt, endedAt: endedAt,
                      createdAt: Date())
    }

    func applies(to set: HCLoggedSet) -> Bool {
        guard set.workoutDate == workoutDate,
              set.sessionKey == sessionKey else { return false }
        if kind == "set" { return set.id == setID }
        guard kind == "workout", let startedAt, let endedAt else { return false }
        return set.completedAt >= startedAt && set.completedAt <= endedAt
    }
}


extension HCWorkoutUndo {
    var apiPayload: [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return [
            "p_id": id.uuidString.lowercased(),
            "p_kind": kind,
            "p_set_id": setID.map { $0.uuidString.lowercased() as Any } ?? NSNull(),
            "p_date": workoutDate,
            "p_session_key": sessionKey,
            "p_started_at": startedAt.map { formatter.string(from: $0) as Any } ?? NSNull(),
            "p_ended_at": endedAt.map { formatter.string(from: $0) as Any } ?? NSNull()
        ]
    }

    static func decodeCloudRows(_ rows: [[String: Any]]) -> [HCWorkoutUndo] {
        let clock = ISO8601DateFormatter()
        clock.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        func parse(_ raw: String?) -> Date? {
            guard let raw else { return nil }
            return clock.date(from: raw) ?? basic.date(from: raw)
        }
        return rows.compactMap { row in
            guard let idString = row["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let kind = row["kind"] as? String,
                  kind == "set" || kind == "workout",
                  let date = row["workout_date"] as? String,
                  let key = row["session_key"] as? String,
                  let created = parse(row["created_at"] as? String)
            else { return nil }
            return HCWorkoutUndo(
                id: id, kind: kind,
                setID: (row["set_id"] as? String).flatMap(UUID.init(uuidString:)),
                workoutDate: date, sessionKey: key,
                startedAt: parse(row["window_started_at"] as? String),
                endedAt: parse(row["window_ended_at"] as? String),
                createdAt: created)
        }
    }

    static func merged(local: [HCWorkoutUndo], cloud: [HCWorkoutUndo])
        -> [HCWorkoutUndo] {
        var byID = Dictionary(uniqueKeysWithValues: cloud.map { ($0.id, $0) })
        for entry in local { byID[entry.id] = entry }
        return byID.values.sorted { $0.createdAt < $1.createdAt }
    }
}

/// The source of truth for progress is a dated exercise/set slot, NOT the
/// device on which a recording started. Every raw record retains its UUID,
/// source, and timestamps for history/export; only the progress presentation
/// is reconciled. Extra sets remain in history but do not inflate the plan.
enum HCSetReconciliation {
    static func allRecords(local: [HCLoggedSet], cloud: [HCLoggedSet],
                           undos: [HCWorkoutUndo] = []) -> [HCLoggedSet] {
        var byID = Dictionary(uniqueKeysWithValues: cloud.map { ($0.id, $0) })
        // Locally edited or pending entries win until confirmed to the cloud.
        for entry in local { byID[entry.id] = entry }
        return byID.values.filter { entry in
            !undos.contains(where: { $0.applies(to: entry) })
        }.sorted {
            if $0.completedAt != $1.completedAt { return $0.completedAt < $1.completedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    /// One visible completion per prescribed exercise/set number.
    /// A later phone or Watch attempt never destroys the earlier raw record.
    static func completed(for workout: HCWorkout, records: [HCLoggedSet]) -> [HCLoggedSet] {
        let exercises = Dictionary(uniqueKeysWithValues: workout.exercises.map { ($0.id, $0) })
        var slots: [String: HCLoggedSet] = [:]
        for entry in records {
            guard entry.workoutID == workout.id,
                  entry.workoutDate == workout.date,
                  entry.sessionKey == workout.sessionKey,
                  let exercise = exercises[entry.exerciseID],
                  (1...max(1, exercise.prescribedSets)).contains(entry.index),
                  exercise.prescribedSets > 0 else { continue }
            let slot = entry.exerciseID + "::" + String(entry.index)
            if let previous = slots[slot] {
                // Newest entry is shown, but the entire raw history survives.
                if entry.completedAt > previous.completedAt ||
                   (entry.completedAt == previous.completedAt &&
                    entry.id.uuidString > previous.id.uuidString) {
                    slots[slot] = entry
                }
            } else {
                slots[slot] = entry
            }
        }
        return slots.values.sorted {
            if $0.exerciseIndex != $1.exerciseIndex {
                return $0.exerciseIndex < $1.exerciseIndex
            }
            return $0.index < $1.index
        }
    }

    static func nextSetIndex(for exercise: HCExercise, workout: HCWorkout,
                             records: [HCLoggedSet]) -> Int {
        let completed = Set(completed(for: workout, records: records)
            .filter { $0.exerciseID == exercise.id }.map(\.index))
        if exercise.prescribedSets > 0 {
            for index in 1...exercise.prescribedSets where !completed.contains(index) {
                return index
            }
        }
        let last = records.filter {
            $0.workoutID == workout.id && $0.exerciseID == exercise.id
        }.map(\.index).max() ?? 0
        return last + 1 // An extra set is allowed, but won't inflate plan progress.
    }

    static func decodeCloudRows(_ rows: [[String: Any]],
                                workout: HCWorkout) -> [HCLoggedSet] {
        let exercises = Dictionary(uniqueKeysWithValues:
            workout.exercises.map { ($0.id, $0) })
        return rows.compactMap { row -> HCLoggedSet? in
            guard let rawID = row["id"] as? String,
                  let id = UUID(uuidString: rawID),
                  let date = row["workout_date"] as? String, date == workout.date,
                  let session = row["session_key"] as? String,
                  session == workout.sessionKey,
                  let exerciseID = row["exercise_id"] as? String,
                  let exercise = exercises[exerciseID],
                  let number = (row["set_index"] as? NSNumber)?.intValue, number > 0,
                  let reps = (row["reps"] as? NSNumber)?.intValue, reps > 0,
                  let recorded = row["completed_at"] as? String,
                  let completedAt = cloudDate(recorded),
                  let position = (row["exercise_index"] as? NSNumber)?.intValue
            else { return nil }
            var entry = HCLoggedSet(id: id, workoutID: workout.id,
                workoutDate: date, sessionKey: session,
                workoutTitle: row["workout_title"] as? String ?? workout.title,
                exerciseID: exerciseID,
                exerciseName: row["exercise_name"] as? String ?? exerciseID,
                exerciseIndex: position, index: number,
                weightLb: (row["weight_lb"] as? NSNumber)?.doubleValue,
                reps: reps,
                rir: (row["rir"] as? NSNumber)?.doubleValue,
                completedAt: completedAt,
                startedAt: (row["started_at"] as? String).flatMap(cloudDate),
                durationSeconds: (row["duration_seconds"] as? NSNumber)?.doubleValue,
                source: row["source"] as? String)
            let storedSide = (row["working_side"] as? String)
                .flatMap(HCWorkingSide.init(rawValue:))
            entry.side = storedSide ?? exercise.side(forSet: number)
            if let raw = row["motion_insight"],
               !(raw is NSNull),
               let data = try? JSONSerialization.data(withJSONObject: raw),
               let insight = try? JSONDecoder().decode(
                    HCMotionSetInsight.self, from: data) {
                entry.motionInsight = insight
            }
            return entry
        }
    }

    /// Decode historical motion sets without needing today's workout plan.
    /// Source IDs, recorded date, physical side and motion provenance survive.
    static func decodeMotionHistoryRows(_ rows: [[String: Any]]) -> [HCLoggedSet] {
        rows.compactMap { row -> HCLoggedSet? in
            guard let idRaw = row["id"] as? String, let id = UUID(uuidString: idRaw),
                  let date = row["workout_date"] as? String, date.count == 10,
                  let sessionKey = row["session_key"] as? String, !sessionKey.isEmpty,
                  let exerciseID = row["exercise_id"] as? String, !exerciseID.isEmpty,
                  let exercise = row["exercise_name"] as? String, !exercise.isEmpty,
                  let setNumber = (row["set_index"] as? NSNumber)?.intValue,
                  (1...300).contains(setNumber),
                  let recordedReps = (row["reps"] as? NSNumber)?.intValue,
                  (1...300).contains(recordedReps),
                  let timestamp = row["completed_at"] as? String,
                  let completed = cloudDate(timestamp),
                  let rawInsight = row["motion_insight"], !(rawInsight is NSNull),
                  JSONSerialization.isValidJSONObject(rawInsight),
                  let insightData = try? JSONSerialization.data(
                    withJSONObject: rawInsight),
                  let insight = try? JSONDecoder().decode(
                    HCMotionSetInsight.self, from: insightData) else { return nil }
            let position = (row["exercise_index"] as? NSNumber)?.intValue ?? 0
            var entry = HCLoggedSet(id: id,
                workoutID: "historical-" + date + "-" + sessionKey,
                workoutDate: date, sessionKey: sessionKey,
                workoutTitle: row["workout_title"] as? String ?? "Strength workout",
                exerciseID: exerciseID, exerciseName: exercise,
                exerciseIndex: position, index: setNumber,
                weightLb: (row["weight_lb"] as? NSNumber)?.doubleValue,
                reps: recordedReps,
                rir: (row["rir"] as? NSNumber)?.doubleValue,
                completedAt: completed,
                startedAt: (row["started_at"] as? String).flatMap(cloudDate),
                durationSeconds: (row["duration_seconds"] as? NSNumber)?.doubleValue,
                source: row["source"] as? String)
            entry.side = (row["working_side"] as? String)
                .flatMap(HCWorkingSide.init(rawValue:))
            entry.motionInsight = insight
            return entry
        }
    }

    private static func cloudDate(_ raw: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }
}


/// Descriptive trends derived from recorded sets. Forecasts are conservative
/// arithmetic projections, NOT clinical fatigue, strength, or form assessment.
struct IMUNMotionForecast: Hashable {
    let exerciseName: String
    let location: String
    let sessionCount: Int
    let lastAverageCycleSeconds: Double
    let projectedNextCycleSeconds: Double
    let trendPercentPerSession: Double
    let confidence: String
    let explanation: String
}

struct IMUNStrengthForecast: Hashable {
    let exerciseName: String
    let sessionCount: Int
    let lastEstimatedMaxLb: Double
    let projectedNextEstimatedMaxLb: Double
    let confidence: String
}

enum IMUNMotionAnalytics {
    static func placement(_ motion: HCMotionSetInsight) -> String {
        motion.wearableLocation ??
        IMUNWearableLocation.fromLegacy(motion.wearSide,
            deviceID:"appleWatch").rawValue
    }

    static func comparableSets(_ records: [HCLoggedSet],
                               exerciseName: String,
                               location: String) -> [HCLoggedSet] {
        let target = HCProgramCatalog.normalized(exerciseName)
        return records.filter { entry in
            guard let detail = entry.motionInsight else { return false }
            return HCProgramCatalog.normalized(entry.exerciseName) == target &&
                detail.source == "Apple Watch" &&
                placement(detail) == location &&
                (detail.averageCycleSeconds ?? 0) > 0.25 &&
                (detail.averageCycleSeconds ?? 0) < 15 &&
                (detail.analysisConfidence != "Low") &&
                (detail.sampleCoveragePercent ?? 100) >= 65
        }.sorted { $0.completedAt < $1.completedAt }
    }

    /// Only same-exercise and same-placement days can be compared.
    /// Requires >= 4 different sessions; predictions are capped to avoid
    /// extrapolating sensor noise into implausible coaching advice.
    static func forecastMotion(_ records: [HCLoggedSet],
                               exerciseName: String, location: String)
        -> IMUNMotionForecast? {
        let samples = comparableSets(records, exerciseName: exerciseName,
                                     location: location)
        let grouped = Dictionary(grouping: samples, by: {
            $0.workoutDate + "/" + $0.sessionKey
        })
        let rows: [(date: Date, value: Double)] = grouped.compactMap { _, sets in
            guard let date = sets.first.map(\.completedAt) else { return nil }
            let values = sets.compactMap { $0.motionInsight?.averageCycleSeconds }
            guard !values.isEmpty else { return nil }
            return (date, values.reduce(0, +) / Double(values.count))
        }.sorted { $0.date < $1.date }
        let recent = Array(rows.suffix(8))
        guard recent.count >= 4, let last = recent.last?.value, last > 0 else {
            return nil
        }
        let values = recent.map(\.value)
        let first = values.first ?? last
        let span = Double(values.count - 1)
        let slope = span > 0 ? (last - first) / span : 0
        let maxChange = last * 0.08
        let projected = max(0.25, last + max(-maxChange, min(maxChange, slope)))
        let percent = last > 0 ? (projected - last) / last * 100 : 0
        let mean = values.reduce(0, +) / Double(values.count)
        let noise = sqrt(values.reduce(0) { $0 + pow($1 - mean, 2) } /
            Double(values.count))
        let stable = noise / max(0.001, mean) < 0.20
        let confidence = recent.count >= 6 && stable ? "Moderate" : "Low"
        return IMUNMotionForecast(
            exerciseName: exerciseName, location: location,
            sessionCount: recent.count,
            lastAverageCycleSeconds: last,
            projectedNextCycleSeconds: projected,
            trendPercentPerSession: percent,
            confidence: confidence,
            explanation: "Projected from \(recent.count) recorded sessions with the same exercise and sensor placement. Cycle timing alone does not establish better technique, strength or readiness."
        )
    }

    static func forecastStrength(_ records: [HCLoggedSet],
                                 exerciseName: String) -> IMUNStrengthForecast? {
        let target = HCProgramCatalog.normalized(exerciseName)
        let eligible = records.filter {
            HCProgramCatalog.normalized($0.exerciseName) == target &&
            ($0.weightLb ?? 0) > 0 && (1...12).contains($0.reps)
        }
        let grouped = Dictionary(grouping: eligible,
            by: { $0.workoutDate + "/" + $0.sessionKey })
        let values: [(Date, Double)] = grouped.compactMap { _, sets in
            guard let date = sets.map(\.completedAt).max() else { return nil }
            let maxima = sets.compactMap { entry -> Double? in
                guard let load = entry.weightLb else { return nil }
                return load * (1 + Double(entry.reps) / 30)
            }
            guard let best = maxima.max() else { return nil }
            return (date, best)
        }.sorted { $0.0 < $1.0 }
        let recent = Array(values.suffix(8))
        guard recent.count >= 4, let first = recent.first?.1,
              let last = recent.last?.1 else { return nil }
        let trend = (last - first) / Double(recent.count - 1)
        let next = max(0, last + max(-last * 0.05,
                                   min(last * 0.05, trend)))
        return IMUNStrengthForecast(
            exerciseName: exerciseName, sessionCount: recent.count,
            lastEstimatedMaxLb: last,
            projectedNextEstimatedMaxLb: next,
            confidence: recent.count >= 6 ? "Moderate" : "Low")
    }
}
