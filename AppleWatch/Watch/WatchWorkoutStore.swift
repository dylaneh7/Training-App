import Foundation
import Combine
import WatchConnectivity

/// Watch data is persisted before transport, so a dropped connection cannot
/// erase completed sets. Each event keeps a stable UUID for cloud deduplication.
final class WatchWorkoutStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var workout: HCWorkout = .preview
    @Published private(set) var sets: [HCLoggedSet] = []
    @Published private(set) var status = "Workout saved on Apple Watch"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var queuedIDs: Set<UUID> = []

    private var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    override init() {
        super.init()
        if let data = try? Data(contentsOf: directory.appendingPathComponent("workout.json")),
           let saved = try? decoder.decode(HCWorkout.self, from: data) {
            workout = saved
        }
        if let data = try? Data(contentsOf: directory.appendingPathComponent("sets.json")),
           let saved = try? decoder.decode([HCLoggedSet].self, from: data) {
            sets = saved
        }
        if let data = try? Data(contentsOf: directory.appendingPathComponent("queued-ids.json")),
           let saved = try? decoder.decode([UUID].self, from: data) {
            queuedIDs = Set(saved)
        }

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            applyContext(WCSession.default.receivedApplicationContext)
        }
    }

    func completedSets(for exercise: HCExercise) -> [HCLoggedSet] {
        sets.filter { $0.workoutID == workout.id && $0.exerciseID == exercise.id }
            .sorted { $0.index < $1.index }
    }

    func log(exercise: HCExercise, weightLb: Double?, reps: Int, rir: Double?) {
        guard reps > 0, reps <= 300,
              weightLb == nil || (weightLb! >= 0 && weightLb! <= 3000)
        else { return }
        let entry = HCLoggedSet(
            id: UUID(),
            workoutID: workout.id,
            workoutDate: workout.date,
            sessionKey: workout.sessionKey,
            workoutTitle: workout.title,
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            exerciseIndex: exercise.exerciseIndex,
            index: completedSets(for: exercise).count + 1,
            weightLb: weightLb,
            reps: reps,
            rir: rir,
            completedAt: Date()
        )
        sets.append(entry)
        save(sets, name: "sets.json")
        sendPending()
    }

    private func save<T: Encodable>(_ value: T, name: String) {
        guard let data = try? encoder.encode(value) else { return }
        do {
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        } catch {
            status = "Local save failed: \(error.localizedDescription)"
        }
    }

    private func applyContext(_ context: [String: Any]) {
        guard let data = context[HCPayload.workout] as? Data,
              let next = try? decoder.decode(HCWorkout.self, from: data)
        else { return }
        DispatchQueue.main.async {
            self.workout = next
            self.save(next, name: "workout.json")
            self.status = "Workout updated from iPhone"
        }
    }

    private func sendPending() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        for entry in sets where !queuedIDs.contains(entry.id) {
            guard let data = try? encoder.encode(entry) else { continue }
            // Works even when the phone is out of range; system queues transfer.
            session.transferUserInfo([
                HCPayload.kind: HCPayload.loggedSet,
                HCPayload.data: data
            ])
            queuedIDs.insert(entry.id)
        }
        save(Array(queuedIDs), name: "queued-ids.json")
        status = "Saved locally; sent or queued for iPhone"
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        if state == .activated {
            DispatchQueue.main.async { self.sendPending() }
        } else if let error {
            DispatchQueue.main.async { self.status = error.localizedDescription }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        applyContext(context)
    }
}
