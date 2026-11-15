import Foundation
import Combine
import WatchConnectivity

/// Timestamp-based clocks survive wrist-down, temporary app suspension, and re-launch.
/// Display timers calculate Date() - start rather than incrementing a foreground counter.
struct HCTrainingClock: Codable {
    let workoutID: String
    var startedAt: Date
    var pausedAt: Date?
    var pausedSeconds: TimeInterval = 0
    var finishedAt: Date?
    var setExerciseID: String?
    var setStartedAt: Date?
    var restEndsAt: Date?
    var splits: [HCRunSplit]? = nil
    var lastLapDistance: Double? = nil

    var isActive: Bool { finishedAt == nil }
    var isPaused: Bool { isActive && pausedAt != nil }
    func duration(at now: Date = Date()) -> TimeInterval {
        let end = finishedAt ?? pausedAt ?? now
        return max(0, end.timeIntervalSince(startedAt) - pausedSeconds)
    }
}

final class WatchWorkoutStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var workout: HCWorkout = .preview
    @Published private(set) var runPlan: HCRunPlan?
    @Published private(set) var runHistory: [HCProgressRun] = []
    @Published private(set) var sets: [HCLoggedSet] = []
    @Published private(set) var completedRuns: [HCRunFinished] = []
    @Published private(set) var liftClock: HCTrainingClock?
    @Published private(set) var guidedExerciseID: String?
    @Published private(set) var runClock: HCTrainingClock?
    @Published private(set) var status = "Ready to train"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var queuedIDs: Set<UUID> = []

    private var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    override init() {
        super.init()
        if let s: HCWorkout = load("workout.json") { workout = s }
        if let s: [HCLoggedSet] = load("sets.json") { sets = s }
        if let s: [UUID] = load("queued-ids.json") { queuedIDs = Set(s) }
        if let s: HCTrainingClock = load("lifting-clock.json") { liftClock = s }
        guidedExerciseID = load("guided-exercise-id.json")
        if let s: HCTrainingClock = load("running-clock.json") { runClock = s }
        if let s: HCRunPlan = load("run-plan.json") { runPlan = s }
        if let s: [HCProgressRun] = load("run-history.json") { runHistory = s }
        if let s: [HCRunFinished] = load("completed-runs.json") { completedRuns = s }

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            applyContext(WCSession.default.receivedApplicationContext)
        }
    }

    private func load<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, name: String) {
        guard let bytes = try? encoder.encode(value) else { return }
        do {
            try bytes.write(to: directory.appendingPathComponent(name), options: .atomic)
        } catch {
            status = "Could not save locally: \(error.localizedDescription)"
        }
    }

    func completedSets(for exercise: HCExercise) -> [HCLoggedSet] {
        sets.filter { $0.workoutID == workout.id && $0.exerciseID == exercise.id }
            .sorted { $0.index < $1.index }
    }

    // MARK: - Guided strength session

    /// The first unfinished movement is the default. Manual selection takes
    /// priority until the final prescribed set is saved.
    var guidedExercise: HCExercise? {
        if let activeID = liftClock?.setExerciseID {
            return workout.exercises.first(where: { $0.id == activeID })
        }
        if let selected = workout.exercises.first(where: { $0.id == guidedExerciseID }),
           completedSets(for: selected).count < selected.prescribedSets {
            return selected
        }
        return workout.exercises.first(where: {
            completedSets(for: $0).count < $0.prescribedSets
        })
    }

    var guidedCompletedSets: Int {
        workout.exercises.reduce(0) { $0 + completedSets(for: $1).count }
    }

    var guidedAllFinished: Bool {
        !workout.exercises.isEmpty &&
        workout.exercises.allSatisfy {
            completedSets(for: $0).count >= $0.prescribedSets
        }
    }

    func selectGuidedExercise(_ exercise: HCExercise) {
        guard liftClock?.setStartedAt == nil,
              workout.exercises.contains(where: { $0.id == exercise.id }) else { return }
        guidedExerciseID = exercise.id
        save(exercise.id, name: "guided-exercise-id.json")
    }

    func moveToNextGuidedExercise() {
        guard liftClock?.setStartedAt == nil, !workout.exercises.isEmpty else { return }
        let index = workout.exercises.firstIndex(where: { $0.id == guidedExerciseID }) ?? -1
        for offset in 1...workout.exercises.count {
            let nextIndex = (index + offset + workout.exercises.count) % workout.exercises.count
            let next = workout.exercises[nextIndex]
            if completedSets(for: next).count < next.prescribedSets {
                selectGuidedExercise(next)
                return
            }
        }
    }

    // MARK: - Full strength session clock

    func startLifting() {
        guard liftClock?.isActive != true && runClock?.isActive != true else { return }
        liftClock = HCTrainingClock(workoutID: workout.id, startedAt: Date())
        let first = workout.exercises.first(where: {
            completedSets(for: $0).count < $0.prescribedSets
        })
        guidedExerciseID = first?.id
        if let first { save(first.id, name: "guided-exercise-id.json") }
        save(liftClock, name: "lifting-clock.json")
    }

    func pauseLifting() {
        guard var clock = liftClock, clock.isActive, !clock.isPaused,
              clock.setStartedAt == nil else { return }
        clock.pausedAt = Date()
        liftClock = clock
        save(clock, name: "lifting-clock.json")
    }

    func resumeLifting() {
        guard var clock = liftClock, clock.isPaused, let paused = clock.pausedAt else { return }
        clock.pausedSeconds += Date().timeIntervalSince(paused)
        clock.pausedAt = nil
        liftClock = clock
        save(clock, name: "lifting-clock.json")
    }

    func endLifting() {
        guard var clock = liftClock, clock.isActive, clock.setStartedAt == nil else { return }
        if let paused = clock.pausedAt {
            clock.pausedSeconds += Date().timeIntervalSince(paused)
            clock.pausedAt = nil
        }
        clock.finishedAt = Date()
        clock.restEndsAt = nil
        liftClock = clock
        save(clock, name: "lifting-clock.json")
    }

    // MARK: - Per-set clock and rest period

    func startSet(for exercise: HCExercise) {
        guard var clock = liftClock, clock.isActive, !clock.isPaused,
              clock.setStartedAt == nil, clock.workoutID == workout.id else { return }
        clock.setExerciseID = exercise.id
        guidedExerciseID = exercise.id
        save(exercise.id, name: "guided-exercise-id.json")
        clock.setStartedAt = Date()
        clock.restEndsAt = nil
        liftClock = clock
        save(clock, name: "lifting-clock.json")
    }

    func cancelSet() {
        guard var clock = liftClock, clock.setStartedAt != nil else { return }
        clock.setStartedAt = nil
        clock.setExerciseID = nil
        liftClock = clock
        save(clock, name: "lifting-clock.json")
    }

    func stopSet(for exercise: HCExercise, weightLb: Double?, reps: Int, rir: Double?) -> Bool {
        guard var clock = liftClock, clock.isActive, !clock.isPaused,
              clock.setExerciseID == exercise.id, let started = clock.setStartedAt,
              reps > 0, reps <= 300,
              weightLb == nil || (weightLb! >= 0 && weightLb! <= 3000),
              rir == nil || ((rir! >= 0) && (rir! <= 10))
        else { return false }

        let now = Date()
        var entry = HCLoggedSet(
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
            completedAt: now
        )
        entry.startedAt = started
        entry.durationSeconds = now.timeIntervalSince(started)
        sets.append(entry)
        save(sets, name: "sets.json")

        clock.setExerciseID = nil
        clock.setStartedAt = nil
        clock.restEndsAt = now.addingTimeInterval(Double(exercise.restSeconds))
        liftClock = clock
        // Present the next remaining set automatically when the rest expires.
        // If this movement has more sets, it stays selected.
        if completedSets(for: exercise).count >= exercise.prescribedSets {
            moveToNextGuidedExercise()
        }
        save(clock, name: "lifting-clock.json")
        sendPending()
        return true
    }

    func skipRest() {
        guard var clock = liftClock else { return }
        clock.restEndsAt = nil
        liftClock = clock
        save(clock, name: "lifting-clock.json")
    }

    // MARK: - Separate running clock and synced run summary

    func startRun() {
        guard runClock?.isActive != true && liftClock?.isActive != true else { return }
        let plan = runPlan
        runClock = HCTrainingClock(workoutID: plan?.id ?? "unscheduled-run", startedAt: Date())
        save(runClock, name: "running-clock.json")
    }

    func pauseRun() {
        guard var clock = runClock, clock.isActive, !clock.isPaused else { return }
        clock.pausedAt = Date()
        runClock = clock
        save(clock, name: "running-clock.json")
    }

    func resumeRun() {
        guard var clock = runClock, clock.isPaused, let start = clock.pausedAt else { return }
        clock.pausedSeconds += Date().timeIntervalSince(start)
        clock.pausedAt = nil
        runClock = clock
        save(clock, name: "running-clock.json")
    }

    func addRunSplit(currentDistanceMeters: Double?) {
        guard var clock=runClock, clock.isActive, !clock.isPaused else { return }
        let elapsed=clock.duration()
        let accumulated=(clock.splits ?? []).reduce(0) { $0+$1.elapsedSeconds }
        let lapTime=elapsed-accumulated
        guard lapTime > 1 else { return }
        let dist=currentDistanceMeters.flatMap { now -> Double? in
            let delta=now-(clock.lastLapDistance ?? 0)
            return delta >= 0 ? delta : nil
        }
        var splits=clock.splits ?? []
        splits.append(HCRunSplit(index:splits.count+1,elapsedSeconds:lapTime,distanceMeters:dist))
        clock.splits=splits
        clock.lastLapDistance=currentDistanceMeters
        runClock=clock
        save(clock,name:"running-clock.json")
    }

    func finishRun(distanceMeters: Double?, heartRateBPM: Double?) {
        guard var clock = runClock, clock.isActive else { return }
        let now = Date()
        clock.finishedAt = now
        runClock = clock
        save(clock, name: "running-clock.json")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = .current
        let result = HCRunFinished(
            id: UUID(),
            planID: runPlan?.id,
            date: dateFormatter.string(from: clock.startedAt),
            startedAt: clock.startedAt,
            endedAt: now,
            distanceMeters: distanceMeters,
            averageHeartRate: heartRateBPM
        )
        let completedTime=clock.duration(at:now)
        let splitSeconds=(clock.splits ?? []).reduce(0) { $0+$1.elapsedSeconds }
        let tail=max(0,completedTime-splitSeconds)
        var splits=clock.splits ?? []
        if tail >= 1 {
            let tailDistance=distanceMeters.flatMap { now -> Double? in
                let value=now-(clock.lastLapDistance ?? 0)
                return value >= 0 ? value : nil
            }
            splits.append(HCRunSplit(index:splits.count+1,elapsedSeconds:tail,distanceMeters:tailDistance))
        }
        var finished=result
        finished.splits=splits
        completedRuns.append(finished)
        save(completedRuns, name: "completed-runs.json")
        sendPending()
    }

    // MARK: - WatchConnectivity

    private func applyContext(_ context: [String: Any]) {
        if let data = context[HCPayload.workout] as? Data,
           let next = try? decoder.decode(HCWorkout.self, from: data) {
            DispatchQueue.main.async {
                if self.liftClock?.isActive == true && self.workout.id != next.id {
                    self.status = "Finish current lift before switching workouts."
                } else {
                    self.workout = next
                    if let currentID = self.guidedExerciseID,
                       !next.exercises.contains(where: { $0.id == currentID }) {
                        self.guidedExerciseID = next.exercises.first?.id
                    }
                    self.save(next, name: "workout.json")
                    self.status = "Workout updated from iPhone"
                }
            }
        }
        if let data = context[HCPayload.runHistory] as? Data,
           let history = try? decoder.decode([HCProgressRun].self, from: data) {
            DispatchQueue.main.async {
                self.runHistory = Array(history.prefix(12))
                self.save(self.runHistory, name: "run-history.json")
                self.status = "Run history updated from iPhone"
            }
        }
        if let data = context[HCPayload.runPlan] as? Data,
           let next = try? decoder.decode(HCRunPlan.self, from: data) {
            DispatchQueue.main.async {
                self.runPlan = next
                self.save(next, name: "run-plan.json")
            }
        }
    }

    private func sendPending() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        let session = WCSession.default
        for entry in sets where !queuedIDs.contains(entry.id) {
            guard let bytes = try? encoder.encode(entry) else { continue }
            session.transferUserInfo([HCPayload.kind: HCPayload.loggedSet, HCPayload.data: bytes])
            queuedIDs.insert(entry.id)
        }
        for run in completedRuns where !queuedIDs.contains(run.id) {
            guard let bytes = try? encoder.encode(run) else { continue }
            session.transferUserInfo([HCPayload.kind: HCPayload.completedRun, HCPayload.data: bytes])
            queuedIDs.insert(run.id)
        }
        save(Array(queuedIDs), name: "queued-ids.json")
        status = "Saved locally · queued for iPhone"
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

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo[HCPayload.kind] as? String == "correctedSet",
              let bytes = userInfo[HCPayload.data] as? Data,
              let corrected = try? decoder.decode(HCLoggedSet.self, from: bytes) else { return }
        DispatchQueue.main.async {
            if let index = self.sets.firstIndex(where: { $0.id == corrected.id }) {
                self.sets[index] = corrected
                self.save(self.sets, name: "sets.json")
                self.status = "Set correction synced from iPhone"
            }
        }
    }
}
