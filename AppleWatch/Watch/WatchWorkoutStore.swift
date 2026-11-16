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
    // Optional so existing persisted clocks from older versions still decode.
    var automaticMilesCompleted: Int? = nil

    var isActive: Bool { finishedAt == nil }
    var isPaused: Bool { isActive && pausedAt != nil }
    func duration(at now: Date = Date()) -> TimeInterval {
        let end = finishedAt ?? pausedAt ?? now
        return max(0, end.timeIntervalSince(startedAt) - pausedSeconds)
    }
}

final class WatchWorkoutStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var workout: HCWorkout = .unscheduled(date: WatchWorkoutStore.today())
    @Published private(set) var scheduleState = "loading"
    @Published private(set) var scheduleUpdatedAt: Date?
    @Published private(set) var hasScheduledLift = false
    @Published private(set) var runPlan: HCRunPlan?
    @Published private(set) var runHistory: [HCProgressRun] = []
    @Published private(set) var recoverySummary: HCRecoveryDatum?
    @Published private(set) var sets: [HCLoggedSet] = []
    @Published private(set) var completedRuns: [HCRunFinished] = []
    @Published private(set) var liftClock: HCTrainingClock?
    @Published private(set) var guidedExerciseID: String?
    @Published private(set) var runClock: HCTrainingClock?
    @Published private(set) var status = "Ready to train"
    @Published private(set) var isRequestingSchedule = false
    @Published private(set) var lastPhoneAcknowledgement: Date?
    private var pendingManualScheduleRequest = false

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var queuedIDs: Set<UUID> = []
    private var confirmedIDs: Set<UUID> = []
    private var latestSchedule: HCWatchSchedule?

    static func today() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    override init() {
        super.init()
        // Never revive the older hardcoded Saturday example or yesterday's cache.
        if let snapshot: HCWatchSchedule = load("latest-schedule.json"),
           snapshot.date == Self.today() {
            applySchedule(snapshot)
        }
        if let s: [HCLoggedSet] = load("sets.json") { sets = s }
        if let s: [UUID] = load("queued-ids.json") { queuedIDs = Set(s) }
        if let s: [UUID] = load("confirmed-ids.json") { confirmedIDs = Set(s) }
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
            requestCurrentSchedule()
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
        invalidatePreviousDayIfNeeded()
        guard hasScheduledLift, workout.date == Self.today(), !workout.exercises.isEmpty,
              liftClock?.isActive != true && runClock?.isActive != true else { return }
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
        if let latestSchedule { applySchedule(latestSchedule) }
        invalidatePreviousDayIfNeeded()
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
        let remaining = workout.exercises.contains { movement in
            let count = completedSets(for: movement).count
            return count < movement.prescribedSets
        }
        let override = UserDefaults.standard.integer(forKey: "hcRestOverrideSeconds")
        let restSeconds = override > 0 ? override : exercise.restSeconds
        clock.restEndsAt = remaining ? now.addingTimeInterval(Double(restSeconds)) : nil
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

    /// Records a measured split at each whole mile. If HealthKit distance has
    /// not arrived, no distance or pace is invented; manual laps still work.
    @discardableResult
    func autoLapIfNeeded(currentDistanceMeters: Double?) -> HCRunSplit? {
        guard let distance = currentDistanceMeters, distance.isFinite,
              distance > 0, var clock = runClock,
              clock.isActive, !clock.isPaused else { return nil }
        let crossed = Int(distance / 1609.344)
        guard crossed > (clock.automaticMilesCompleted ?? 0) else { return nil }
        let previous = clock.splits?.count ?? 0
        // Persist the crossing before the spoken cue so background/foreground
        // transitions never repeat the same mile announcement.
        clock.automaticMilesCompleted = crossed
        runClock = clock
        save(clock, name: "running-clock.json")
        addRunSplit(currentDistanceMeters: distance)
        guard let latest = runClock?.splits?.last,
              latest.index > previous else { return nil }
        return latest
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

    private func invalidatePreviousDayIfNeeded() {
        let today = Self.today()
        guard latestSchedule?.date != today else { return }
        scheduleState = "loading"
        scheduleUpdatedAt = nil
        latestSchedule = nil
        runPlan = nil
        hasScheduledLift = false
        // Preserve an in-progress workout until the user finishes it.
        if liftClock?.isActive != true {
            workout = .unscheduled(date: today)
            guidedExerciseID = nil
        }
    }

    private func applySchedule(_ schedule: HCWatchSchedule) {
        guard schedule.date == Self.today() else {
            invalidatePreviousDayIfNeeded()
            return
        }
        if let previous = latestSchedule, previous.date == schedule.date,
           previous.generatedAt > schedule.generatedAt { return }
        latestSchedule = schedule
        isRequestingSchedule = false
        scheduleState = schedule.state
        scheduleUpdatedAt = schedule.generatedAt
        if schedule.state == "ready" {
            runPlan = schedule.runPlan?.date == schedule.date ? schedule.runPlan : nil
            hasScheduledLift = schedule.workout?.date == schedule.date
            if liftClock?.isActive == true && workout.id != schedule.workout?.id {
                // Do not interrupt a recording when another device edits the plan.
                status = "Schedule changed; active workout preserved until finish."
            } else {
                workout = schedule.workout?.date == schedule.date
                    ? schedule.workout! : .unscheduled(date: schedule.date)
                if let selected = guidedExerciseID,
                   !workout.exercises.contains(where: { $0.id == selected }) {
                    guidedExerciseID = workout.exercises.first?.id
                }
                status = hasScheduledLift ? "Today synced from iPhone" : "Rest day · No lift scheduled"
            }
        } else if schedule.state == "signedOut" {
            hasScheduledLift = false
            runPlan = nil
            if liftClock?.isActive != true { workout = .unscheduled(date: schedule.date) }
            status = "Sign in on your iPhone to view the training plan."
        } else {
            // A failed/ongoing cloud refresh must not masquerade as a rest day.
            status = "Checking today's iPhone schedule…"
            if liftClock?.isActive != true && !hasScheduledLift {
                workout = .unscheduled(date: schedule.date)
            }
        }
        save(schedule, name: "latest-schedule.json")
    }

    /// A manual Refresh must request NEW calendar data, not merely echo the
    /// last context. Queue an offline request when live messaging is unavailable.
    func requestCurrentSchedule(manual: Bool = false) {
        invalidatePreviousDayIfNeeded()
        guard WCSession.isSupported() else {
            status = "iPhone sync isn't supported on this Watch."
            isRequestingSchedule = false
            return
        }
        let session = WCSession.default
        if manual {
            isRequestingSchedule = true
            status = "Checking iPhone for your latest workout…"
        }
        guard session.activationState == .activated else {
            if manual { pendingManualScheduleRequest = true }
            status = "Connecting to iPhone…"
            session.activate()
            return
        }
        let request: [String: Any] = [
            HCPayload.kind: HCPayload.requestSchedule,
            "forceRefresh": manual
        ]
        if session.isReachable {
            session.sendMessage(request, replyHandler: { [weak self] response in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isRequestingSchedule = false
                    self.applyContext(response)
                    if response["refreshing"] as? Bool == true {
                        self.status = "Checking Command Center for today's plan…"
                    }
                }
            }, errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if manual {
                        self.queueScheduleRequest(session)
                    } else {
                        self.status = "iPhone not reachable · " + error.localizedDescription
                    }
                }
            })
        } else if manual {
            queueScheduleRequest(session)
        } else {
            status = scheduleState == "ready" ?
                "Showing last confirmed plan · iPhone offline" :
                "Open imun on iPhone for today's workout"
        }
    }

    private func queueScheduleRequest(_ session: WCSession) {
        guard session.activationState == .activated else {
            pendingManualScheduleRequest = true
            status = "Waiting to connect to iPhone…"
            return
        }
        let alreadyQueued = session.outstandingUserInfoTransfers.contains { transfer in
            (transfer.userInfo[HCPayload.kind] as? String) == HCPayload.requestSchedule
        }
        if !alreadyQueued {
            session.transferUserInfo([
                HCPayload.kind: HCPayload.requestSchedule,
                "forceRefresh": true,
                "requestedAt": Date()
            ])
        }
        isRequestingSchedule = false
        status = "Refresh queued · open imun on your iPhone to receive it"
    }

    private func markConfirmed(_ id: UUID) {
        guard !confirmedIDs.contains(id) else { return }
        confirmedIDs.insert(id)
        save(Array(confirmedIDs), name: "confirmed-ids.json")
        lastPhoneAcknowledgement = Date()
        status = "Workout received by iPhone"
    }

    /// A real Send to iPhone action: immediately retry any watch workouts that
    /// have no outstanding transfer, even if previously marked as queued.
    func sendToPhone() {
        guard WCSession.isSupported() else {
            status = "Watch-to-iPhone sync is unavailable."
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated else {
            status = "Connecting to iPhone…"
            session.activate()
            return
        }
        sendPending(forceResend: true)
        if session.isReachable {
            session.sendMessage([HCPayload.kind: HCPayload.syncRequest],
                                replyHandler: { [weak self] reply in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if reply["saved"] as? Bool == true {
                        self.lastPhoneAcknowledgement = Date()
                        self.status = "iPhone connected · awaiting workout receipts"
                    } else {
                        self.status = "Waiting for iPhone to accept workout data"
                    }
                }
            }, errorHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.status = "Workouts queued · open imun on your iPhone"
                }
            })
        } else {
            status = "Workouts queued · open imun on your iPhone"
        }
    }

    private func applyContext(_ context: [String: Any]) {
        // Preferences are cheap to apply even while the plan is loading.
        if let color = context[HCPayload.accentStyle] as? String,
           ["crimson", "lime", "aqua", "white"].contains(color) {
            UserDefaults.standard.set(color, forKey: "hcAccentStyle")
        }
        if let weightStep = context[HCPayload.weightIncrement] as? Double,
           [2.5, 5.0, 10.0].contains(weightStep) {
            UserDefaults.standard.set(weightStep, forKey: "hcWeightIncrement")
        }
        if let rest = context[HCPayload.restOverride] as? Int,
           [0, 60, 90, 120, 180].contains(rest) {
            UserDefaults.standard.set(rest, forKey: "hcRestOverrideSeconds")
        }
        if let haptics = context[HCPayload.watchHaptics] as? Bool {
            UserDefaults.standard.set(haptics, forKey: "hcWatchHaptics")
        }
        if let voice = context["hcRunVoiceCues"] as? Bool {
            UserDefaults.standard.set(voice, forKey: "hcRunVoiceCues")
        }
        if let laps = context["hcRunAutoLaps"] as? Bool {
            UserDefaults.standard.set(laps, forKey: "hcRunAutoLaps")
        }
        if let intervals = context["hcRunIntervals"] as? Bool {
            UserDefaults.standard.set(intervals, forKey: "hcRunIntervals")
        }
        if let cadence = context["hcRunCueMinutes"] as? Int,
           [0, 1, 2, 5, 10].contains(cadence) {
            UserDefaults.standard.set(cadence, forKey: "hcRunCueMinutes")
        }
        if let data = context[HCPayload.schedule] as? Data,
           let snapshot = try? decoder.decode(HCWatchSchedule.self, from: data) {
            DispatchQueue.main.async { self.applySchedule(snapshot) }
        }
        if let data = context["hcRecoverySnapshot"] as? Data,
           let reading = try? decoder.decode(HCRecoveryDatum.self, from: data) {
            DispatchQueue.main.async { self.recoverySummary = reading }
        }
        if let data = context[HCPayload.runHistory] as? Data,
           let history = try? decoder.decode([HCProgressRun].self, from: data) {
            DispatchQueue.main.async {
                self.runHistory = Array(history.prefix(12))
                self.save(self.runHistory, name: "run-history.json")
            }
        }
    }

    private func sendPending(forceResend: Bool = false) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        let session = WCSession.default
        var inFlight = Set<UUID>()
        for transfer in session.outstandingUserInfoTransfers {
            guard let kind = transfer.userInfo[HCPayload.kind] as? String,
                  let bytes = transfer.userInfo[HCPayload.data] as? Data else { continue }
            if kind == HCPayload.loggedSet,
               let item = try? decoder.decode(HCLoggedSet.self, from: bytes) {
                inFlight.insert(item.id)
            } else if kind == HCPayload.completedRun,
                      let run = try? decoder.decode(HCRunFinished.self, from: bytes) {
                inFlight.insert(run.id)
            }
        }
        var newTransfers = 0
        for entry in sets where !confirmedIDs.contains(entry.id) &&
            (!queuedIDs.contains(entry.id) ||
             (forceResend && !inFlight.contains(entry.id))) {
            guard let bytes = try? encoder.encode(entry) else { continue }
            let packet: [String: Any] = [
                HCPayload.kind: HCPayload.loggedSet, HCPayload.data: bytes
            ]
            session.transferUserInfo(packet)
            if session.isReachable {
                session.sendMessage(packet, replyHandler: { [weak self] reply in
                    if reply["saved"] as? Bool == true {
                        DispatchQueue.main.async {
                            self?.markConfirmed(entry.id)
                        }
                    }
                }, errorHandler: { _ in /* reliable background transfer remains */ })
            }
            queuedIDs.insert(entry.id)
            newTransfers += 1
        }
        for run in completedRuns where !confirmedIDs.contains(run.id) &&
            (!queuedIDs.contains(run.id) ||
             (forceResend && !inFlight.contains(run.id))) {
            guard let bytes = try? encoder.encode(run) else { continue }
            let packet: [String: Any] = [
                HCPayload.kind: HCPayload.completedRun, HCPayload.data: bytes
            ]
            session.transferUserInfo(packet)
            if session.isReachable {
                session.sendMessage(packet, replyHandler: { [weak self] reply in
                    if reply["saved"] as? Bool == true {
                        DispatchQueue.main.async {
                            self?.markConfirmed(run.id)
                        }
                    }
                }, errorHandler: { _ in /* reliable background transfer remains */ })
            }
            queuedIDs.insert(run.id)
            newTransfers += 1
        }
        save(Array(queuedIDs), name: "queued-ids.json")
        if newTransfers > 0 {
            status = "\(newTransfers) workout item(s) queued for iPhone"
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        if state == .activated {
            DispatchQueue.main.async {
                self.sendPending()
                let manual = self.pendingManualScheduleRequest
                self.pendingManualScheduleRequest = false
                self.requestCurrentSchedule(manual: manual)
            }
        } else if let error {
            DispatchQueue.main.async { self.status = error.localizedDescription }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        applyContext(context)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if message[HCPayload.kind] as? String == HCPayload.pushSchedule {
            applyContext(message)
            replyHandler(["received": true])
        } else {
            replyHandler(["received": false])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if userInfo[HCPayload.kind] as? String == HCPayload.pushSchedule {
            applyContext(userInfo)
            return
        }
        if userInfo[HCPayload.kind] as? String == HCPayload.syncReceipt {
            if let raw = userInfo["recordID"] as? String,
               let id = UUID(uuidString: raw) {
                DispatchQueue.main.async { self.markConfirmed(id) }
            }
            return
        }
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
