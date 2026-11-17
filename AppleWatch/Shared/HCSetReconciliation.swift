import Foundation

/// The source of truth for progress is a dated exercise/set slot, NOT the
/// device on which a recording started. Every raw record retains its UUID,
/// source, and timestamps for history/export; only the progress presentation
/// is reconciled. Extra sets remain in history but do not inflate the plan.
enum HCSetReconciliation {
    static func allRecords(local: [HCLoggedSet], cloud: [HCLoggedSet]) -> [HCLoggedSet] {
        var byID = Dictionary(uniqueKeysWithValues: cloud.map { ($0.id, $0) })
        // Locally edited or pending entries win until confirmed to the cloud.
        for entry in local { byID[entry.id] = entry }
        return byID.values.sorted {
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
        let exercises = Set(workout.exercises.map(\.id))
        return rows.compactMap { row -> HCLoggedSet? in
            guard let rawID = row["id"] as? String,
                  let id = UUID(uuidString: rawID),
                  let date = row["workout_date"] as? String, date == workout.date,
                  let session = row["session_key"] as? String,
                  session == workout.sessionKey,
                  let exerciseID = row["exercise_id"] as? String,
                  exercises.contains(exerciseID),
                  let number = (row["set_index"] as? NSNumber)?.intValue, number > 0,
                  let reps = (row["reps"] as? NSNumber)?.intValue, reps > 0,
                  let recorded = row["completed_at"] as? String,
                  let completedAt = cloudDate(recorded),
                  let position = (row["exercise_index"] as? NSNumber)?.intValue
            else { return nil }
            let entry = HCLoggedSet(id: id, workoutID: workout.id,
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
