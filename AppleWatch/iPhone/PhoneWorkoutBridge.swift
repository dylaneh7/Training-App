import Foundation
import Combine
import WatchConnectivity

/// Observable iPhone coordinator: five app tabs share the same current date,
/// cloud session, exercise history and WatchConnectivity queues.
final class PhoneWorkoutBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var workout: HCWorkout?
    @Published private(set) var runPlan: HCRunPlan?
    @Published private(set) var loggedSets: [HCLoggedSet] = []
    @Published private(set) var completedWatchRuns: [HCRunFinished] = []
    @Published private(set) var runHistory: [HCProgressRun] = []
    @Published private(set) var recoveryHistory: [HCRecoveryDatum] = []
    @Published private(set) var performanceHistory: [HCPerformanceSet] = []
    @Published private(set) var status = "Preparing Health Coach…"
    @Published private(set) var signedIn = false
    @Published private(set) var loading = false
    @Published private(set) var savingPlan = false
    @Published private(set) var cloudPendingCount = 0
    @Published private(set) var phoneSessionStartedAt: Date?
    @Published private(set) var phoneSetExerciseID: String?
    @Published private(set) var phoneSetStartedAt: Date?
    @Published private(set) var phoneRestEndsAt: Date?

    private let cloud = HCCloudClient()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var uploadedIDs: Set<UUID> = []
    private var syncingQueue = false
    private var pendingEditedWorkout: HCWorkout?

    private var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private func local(_ name: String) -> URL { directory.appendingPathComponent(name) }
    private func read<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: local(name)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
    private func save<T: Encodable>(_ value: T, name: String) {
        guard let data = try? encoder.encode(value) else { return }
        do {
            try data.write(to: local(name), options: .atomic)
        } catch {
            status = "Local save failed: \(error.localizedDescription)"
        }
    }

    override init() {
        super.init()
        loggedSets = read("health-coach-watch-sets.json") ?? []
        completedWatchRuns = read("health-coach-native-runs.json") ?? []
        uploadedIDs = Set(read("uploaded-watch-set-ids.json") ?? [])
        pendingEditedWorkout = read("pending-edited-workout.json")
        phoneSessionStartedAt = read("iphone-session-start.json")
        phoneSetStartedAt = read("iphone-set-start.json")
        phoneSetExerciseID = read("iphone-set-exercise.json")
        phoneRestEndsAt = read("iphone-rest-end.json")
        workout = pendingEditedWorkout
        updatePendingCount()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        } else {
            status = "Watch Connectivity is unavailable on this device."
        }
        Task {
            let user = await cloud.signedInUserID
            DispatchQueue.main.async {
                self.signedIn = user != nil
                if user != nil { self.refresh(date: Date()) }
            }
        }
    }

    func login(email: String, password: String, date: Date) {
        guard !email.isEmpty && !password.isEmpty else {
            status = "Enter your Health Coach email and password."
            return
        }
        loading = true
        status = "Signing in…"
        Task {
            do {
                _ = try await cloud.signIn(email: email, password: password)
                DispatchQueue.main.async {
                    self.signedIn = true
                    self.loading = false
                    self.status = "Signed in to Health Coach"
                    self.refresh(date: date)
                }
            } catch {
                DispatchQueue.main.async {
                    self.loading = false
                    self.status = "Sign in failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func logout() {
        Task { await cloud.signOut() }
        signedIn = false
        status = "Signed out. Local workouts and sets are preserved."
    }

    func suggestion(for exercise: HCExercise, on date: String,
                    aggressive: Bool = true) -> HCLoadSuggestion {
        let relevant = performanceHistory.filter { $0.date < date }
        let lastDate = relevant.sorted { $0.date > $1.date }.first?.date
        let returned = lastDate.flatMap { HCPlanBuilder.startOfDate($0) }
            .map { Date().timeIntervalSince($0) > 21 * 86400 } ?? false
        return HCProgressionEngine.suggest(exercise, history: relevant,
                                          aggressive: aggressive, returning: returned)
    }

    private func smartTargets(_ plan: HCWorkout, history: [HCPerformanceSet]) -> HCWorkout {
        let smartExercises = plan.exercises.map { exercise -> HCExercise in
            let target = HCProgressionEngine.suggest(exercise,
                history: history.filter { $0.date < plan.date },
                returning: plan.sessionKey.hasSuffix("SatUpper"))
            return HCExercise(id:exercise.id, name:exercise.name,
                originalName:exercise.originalName,exerciseIndex:exercise.exerciseIndex,
                prescribedSets:exercise.prescribedSets,repMin:exercise.repMin,repMax:exercise.repMax,
                suggestedWeightLb:exercise.suggestedWeightLb ?? target.weightLb,
                restSeconds:exercise.restSeconds)
        }
        return HCWorkout(id:plan.id,date:plan.date,sessionKey:plan.sessionKey,
                         title:plan.title,exercises:smartExercises,isPreview:false)
    }

    func refresh(date: Date) {
        guard signedIn else { status = "Sign in to load your plan."; return }
        loading = true
        status = "Refreshing workouts and training history…"
        Task {
            do {
                let snapshot = try await cloud.fetchPlannerAndHistory()
                let dateText = HCPlanBuilder.dateString(date)
                let watchHistory = (try? await cloud.fetchWatchPerformance(before:dateText)) ?? []
                let history = HCPlanBuilder.performanceHistory(from:snapshot.history,before:date)
                    + watchHistory
                let saved = try? await cloud.fetchPublishedPlan(date:dateText)
                let baseline = saved ?? HCPlanBuilder.workout(for:date,planner:snapshot.planner,
                                                              history:snapshot.history)
                let active = pendingEditedWorkout?.date == dateText
                    ? pendingEditedWorkout : baseline.map { smartTargets($0,history:history) }
                let run = HCPlanBuilder.run(for:date,planner:snapshot.planner)
                let priorRuns = (try? await cloud.fetchRunHistory()) ?? []
                let recovery = (try? await cloud.fetchRecoveryHistory()) ?? []

                DispatchQueue.main.async {
                    self.workout = active
                    self.runPlan = run
                    self.performanceHistory = history
                    self.runHistory = priorRuns
                    self.recoveryHistory = recovery
                    self.loading = false
                    self.status = active == nil ? "No strength session on this date." :
                        "Workout ready: \(active!.title)"
                    self.sendToWatch()
                    self.retryPendingCloudSets()
                    self.retryPendingWorkout()
                }
            } catch {
                DispatchQueue.main.async {
                    self.loading = false
                    self.status = "Unable to refresh: \(error.localizedDescription)"
                    self.retryPendingCloudSets()
                }
            }
        }
    }

    func newWorkout(date: Date, title: String) {
        let day = HCPlanBuilder.dateString(date)
        let key = HCPlanBuilder.sessionKey(for:date)
            ?? day.replacingOccurrences(of:"-",with:"") + "-Custom"
        let plan = HCWorkout(id:"\(day)-\(key)",date:day,sessionKey:key,
                             title:title.isEmpty ? "Custom Strength Workout" : title,
                             exercises:[],isPreview:false)
        saveEditedWorkout(plan)
    }

    func saveEditedWorkout(_ plan: HCWorkout) {
        workout = plan
        pendingEditedWorkout = plan
        save(plan,name:"pending-edited-workout.json")
        status = "Workout saved locally; syncing to watch and cloud…"
        sendToWatch()
        retryPendingWorkout()
    }

    func retryPendingWorkout() {
        guard signedIn, !savingPlan, let toSave = pendingEditedWorkout else { return }
        savingPlan = true
        Task {
            do {
                try await cloud.saveWorkout(toSave)
                DispatchQueue.main.async {
                    // An edit may have occurred while the previous version saved.
                    if self.pendingEditedWorkout?.id == toSave.id &&
                        self.pendingEditedWorkout?.exercises == toSave.exercises &&
                        self.pendingEditedWorkout?.title == toSave.title {
                        self.pendingEditedWorkout = nil
                        try? FileManager.default.removeItem(at:self.local("pending-edited-workout.json"))
                    }
                    self.savingPlan = false
                    self.status = "Workout edits synced to Health Coach"
                    if self.pendingEditedWorkout != nil { self.retryPendingWorkout() }
                }
            } catch {
                DispatchQueue.main.async {
                    self.savingPlan = false
                    self.status = "Workout changes saved offline; cloud retry available: \(error.localizedDescription)"
                }
            }
        }
    }

    func sendToWatch() {
        guard WCSession.isSupported() else { return }
        let connection = WCSession.default
        guard connection.activationState == .activated,
              connection.isPaired, connection.isWatchAppInstalled else {
            status = "Install the Health Coach watch companion, then send again."
            return
        }
        do {
            var context:[String:Any] = [:]
            if let workout {context[HCPayload.workout] = try encoder.encode(workout)}
            if let runPlan {context[HCPayload.runPlan] = try encoder.encode(runPlan)}
            if !context.isEmpty {
                try connection.updateApplicationContext(context)
                status = "Workout and run sent or queued for watch."
            }
        } catch {
            status = "Watch transfer failed: \(error.localizedDescription)"
        }
    }

    func startPhoneWorkout() {
        guard phoneSessionStartedAt == nil else { return }
        let started = Date()
        phoneSessionStartedAt = started
        save(started,name:"iphone-session-start.json")
    }

    func finishPhoneWorkout() {
        guard phoneSetStartedAt == nil else { return }
        phoneSessionStartedAt = nil
        phoneRestEndsAt = nil
        try? FileManager.default.removeItem(at: local("iphone-session-start.json"))
        try? FileManager.default.removeItem(at: local("iphone-rest-end.json"))
    }

    func startPhoneSet(exercise: HCExercise) {
        guard phoneSessionStartedAt != nil, phoneSetStartedAt == nil else { return }
        phoneSetExerciseID = exercise.id
        phoneSetStartedAt = Date()
        phoneRestEndsAt = nil
        save(exercise.id,name:"iphone-set-exercise.json")
        save(phoneSetStartedAt,name:"iphone-set-start.json")
    }

    func cancelPhoneSet() {
        phoneSetExerciseID = nil
        phoneSetStartedAt = nil
        try? FileManager.default.removeItem(at: local("iphone-set-exercise.json"))
        try? FileManager.default.removeItem(at: local("iphone-set-start.json"))
    }

    func logFromPhone(exercise: HCExercise, weightLb: Double?, reps: Int, rir: Double?) {
        guard let workout, reps > 0, reps <= 300,
              weightLb == nil || (weightLb! >= 0 && weightLb! <= 3000) else { return }
        let existing = loggedSets.filter {
            $0.workoutID == workout.id && $0.exerciseID == exercise.id
        }.count
        var entry = HCLoggedSet(id:UUID(),workoutID:workout.id,workoutDate:workout.date,
                                sessionKey:workout.sessionKey,workoutTitle:workout.title,
                                exerciseID:exercise.id,exerciseName:exercise.name,
                                exerciseIndex:exercise.exerciseIndex,index:existing+1,
                                weightLb:weightLb,reps:reps,rir:rir,completedAt:Date())
        entry.source = "iPhone"
        if phoneSetExerciseID == exercise.id, let started = phoneSetStartedAt {
            entry.startedAt = started
            entry.durationSeconds = Date().timeIntervalSince(started)
            cancelPhoneSet()
            phoneRestEndsAt = Date().addingTimeInterval(Double(exercise.restSeconds))
            save(phoneRestEndsAt,name:"iphone-rest-end.json")
        }
        acceptSet(entry)
    }

    func correctLoggedSet(id: UUID, weightLb: Double?, reps: Int, rir: Double?) {
        guard reps > 0, reps <= 300, let index=loggedSets.firstIndex(where:{$0.id==id}),
              weightLb == nil || (weightLb! >= 0 && weightLb! <= 3000),
              rir == nil || (rir! >= 0 && rir! <= 10)
        else { return }
        let previous=loggedSets[index]
        var corrected=HCLoggedSet(id:previous.id,workoutID:previous.workoutID,
            workoutDate:previous.workoutDate,sessionKey:previous.sessionKey,
            workoutTitle:previous.workoutTitle,exerciseID:previous.exerciseID,
            exerciseName:previous.exerciseName,exerciseIndex:previous.exerciseIndex,
            index:previous.index,weightLb:weightLb,reps:reps,rir:rir,
            completedAt:previous.completedAt)
        corrected.startedAt=previous.startedAt
        corrected.durationSeconds=previous.durationSeconds
        corrected.source=previous.source
        loggedSets[index]=corrected
        save(loggedSets,name:"health-coach-watch-sets.json")
        uploadedIDs.remove(id)
        save(Array(uploadedIDs),name:"uploaded-watch-set-ids.json")
        updatePendingCount()
        if WCSession.isSupported(), WCSession.default.activationState == .activated,
           let bytes=try? encoder.encode(corrected) {
            WCSession.default.transferUserInfo([HCPayload.kind:"correctedSet",
                                                HCPayload.data:bytes])
        }
        status="Updated set saved locally; syncing correction…"
        retryPendingCloudSets()
    }

    func skipPhoneRest() {
        phoneRestEndsAt = nil
        try? FileManager.default.removeItem(at: local("iphone-rest-end.json"))
    }

    private func updatePendingCount() {
        cloudPendingCount = loggedSets.filter { !uploadedIDs.contains($0.id) }.count +
            completedWatchRuns.filter { !uploadedIDs.contains($0.id) }.count
    }

    private func acceptSet(_ entry: HCLoggedSet) {
        guard !loggedSets.contains(where:{$0.id == entry.id}) else { return }
        loggedSets.append(entry)
        save(loggedSets,name:"health-coach-watch-sets.json")
        updatePendingCount()
        status = "Set saved locally"
        retryPendingCloudSets()
    }

    private func acceptRun(_ entry: HCRunFinished) {
        guard !completedWatchRuns.contains(where:{$0.id == entry.id}) else { return }
        completedWatchRuns.append(entry)
        save(completedWatchRuns,name:"health-coach-native-runs.json")
        updatePendingCount()
        status = "Run saved locally"
        retryPendingCloudSets()
    }

    func retryPendingCloudSets() {
        guard signedIn, !syncingQueue else { return }
        let pendingSets = loggedSets.filter { !uploadedIDs.contains($0.id) }
        let pendingRuns = completedWatchRuns.filter { !uploadedIDs.contains($0.id) }
        guard !pendingSets.isEmpty || !pendingRuns.isEmpty else { return }
        syncingQueue = true
        Task {
            var errorMessage: String?
            var savedIDs:[UUID] = []
            for s in pendingSets {
                do { try await cloud.upload(s); savedIDs.append(s.id) }
                catch { errorMessage=error.localizedDescription; break }
            }
            if errorMessage == nil {
                for r in pendingRuns {
                    do { try await cloud.upload(r); savedIDs.append(r.id) }
                    catch { errorMessage=error.localizedDescription; break }
                }
            }
            DispatchQueue.main.async {
                self.uploadedIDs.formUnion(savedIDs)
                self.save(Array(self.uploadedIDs),name:"uploaded-watch-set-ids.json")
                self.updatePendingCount()
                self.syncingQueue = false
                self.status = errorMessage.map {
                    "Saved offline. Sync will retry: \($0)"
                } ?? "Workout data synced"
            }
        }
    }

    // MARK: - Watch Connectivity

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if state == .activated {
                self.sendToWatch()
                self.retryPendingCloudSets()
            } else if let error {
                self.status = "Watch not ready: \(error.localizedDescription)"
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let kind = userInfo[HCPayload.kind] as? String,
              let payload = userInfo[HCPayload.data] as? Data else { return }
        switch kind {
        case HCPayload.loggedSet:
            guard let item = try? decoder.decode(HCLoggedSet.self,from:payload) else { return }
            DispatchQueue.main.async { self.acceptSet(item) }
        case HCPayload.completedRun:
            guard let item = try? decoder.decode(HCRunFinished.self,from:payload) else { return }
            DispatchQueue.main.async { self.acceptRun(item) }
        default: break
        }
    }
}
