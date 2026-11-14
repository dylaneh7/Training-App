import Foundation
import Combine
import WatchConnectivity

/// Offline-first watch store. A logged set is saved locally before being
/// queued for the phone; losing Bluetooth connectivity does not lose the set.
final class WatchWorkoutStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var workout: HCWorkout = .preview
    @Published private(set) var sets: [HCLoggedSet] = []

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func completedSets(for exercise: HCExercise) -> [HCLoggedSet] {
        sets.filter { $0.workoutID == workout.id && $0.exerciseID == exercise.id }
            .sorted { $0.index < $1.index }
    }

    func log(exercise: HCExercise, weightLb: Double, reps: Int) {
        guard reps > 0, weightLb >= 0 else { return }
        let entry = HCLoggedSet(
            id: UUID(),
            workoutID: workout.id,
            exerciseID: exercise.id,
            index: completedSets(for: exercise).count + 1,
            weightLb: weightLb,
            reps: reps,
            completedAt: Date()
        )
        sets.append(entry)
        save(sets, filename: "sets.json")

        if WCSession.isSupported(),
           let payload = try? encoder.encode(entry) {
            WCSession.default.transferUserInfo([
                "kind": "loggedSet",
                "payload": payload
            ])
        }
    }

    private func save<T: Encodable>(_ value: T, filename: String) {
        guard let payload = try? encoder.encode(value) else { return }
        do {
            try payload.write(to: directory.appendingPathComponent(filename), options: .atomic)
        } catch {
            NSLog("Health Coach local save failed: %@", error.localizedDescription)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        guard let payload = context["workout"] as? Data,
              let received = try? decoder.decode(HCWorkout.self, from: payload)
        else { return }
        DispatchQueue.main.async {
            self.workout = received
            self.save(received, filename: "workout.json")
        }
    }
}
