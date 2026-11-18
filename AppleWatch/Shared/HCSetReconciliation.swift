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

    private static func cloudDate(_ raw: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }
}
