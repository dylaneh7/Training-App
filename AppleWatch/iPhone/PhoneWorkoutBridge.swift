import Foundation
import Combine
import WatchConnectivity

/// Observable IMUN coordinator: today's workout, editable upcoming schedule,
/// historical training sources and WatchConnectivity queues.
final class PhoneWorkoutBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var workout: HCWorkout?
    @Published private(set) var runPlan: HCRunPlan?
    @Published private(set) var loggedSets: [HCLoggedSet] = []
    @Published private(set) var completedWatchRuns: [HCRunFinished] = []
    @Published private(set) var runHistory: [HCProgressRun] = []
    @Published private(set) var plannedSessions: [HCPlannedSession] = []
    @Published private(set) var trainingActivities: [HCTrainingActivity] = []
    private var cloudTrainingActivities: [HCTrainingActivity] = []
    private var cloudRecoveryHistory: [HCRecoveryDatum] = []
    private var tredictSnapshot = HCTredictSnapshot()
    @Published private(set) var movingWorkoutID: String?
    @Published private(set) var lastArchiveAt: Date?
    // Apple Health running results stay on device unless user elects to share them.
    private var importedHealthRuns: [HCProgressRun] = []
    private var remoteRunHistory: [HCProgressRun] = []
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
    // A plan is authoritative only after today's Command Center refresh succeeds.
    private var confirmedScheduleDate: String?
    private var refreshGeneration = 0
    private var scheduleRefreshing = false

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

    /// Keep a complete, private, source-labelled on-device snapshot of the
    /// original planner and historical training JSON. Normalized charts are
    /// convenient, but must not silently discard legacy details.
    var legacyArchiveURL: URL? {
        let url = local("imun-original-training-archive.json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func saveOriginalSources(planner: [String: Any], history: [String: Any],
                                     activities: [HCTrainingActivity],
                                     recovery: [HCRecoveryDatum]) {
        guard let activityBytes = try? encoder.encode(activities),
              let recoveryBytes = try? encoder.encode(recovery),
              let activityJSON = try? JSONSerialization.jsonObject(with: activityBytes),
              let recoveryJSON = try? JSONSerialization.jsonObject(with: recoveryBytes)
        else { return }
        let snapshot: [String: Any] = [
            "format": "imun-original-sources-v1",
            "archivedAt": ISO8601DateFormatter().string(from: Date()),
            "plannerState": planner,
            "hybridCoachState": history,
            "workoutCompletionEvents": activityJSON,
            "recoveryDailyMetrics": recoveryJSON
        ]
        guard JSONSerialization.isValidJSONObject(snapshot),
              let bytes = try? JSONSerialization.data(withJSONObject: snapshot,
                                                      options: [.prettyPrinted, .sortedKeys])
        else { return }
        let file = local("imun-original-training-archive.json")
        do {
            try bytes.write(to: file, options: .atomic)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: file.path)
            lastArchiveAt = Date()
        } catch {
            status = "Training history loaded; original archive failed: \(error.localizedDescription)"
        }
    }

    override init() {
        super.init()
        loggedSets = read("health-coach-watch-sets.json") ?? []
        lastArchiveAt = read("imun-source-archive-date.json")
        plannedSessions = read("imun-planned-workouts.json") ?? []
        cloudTrainingActivities = read("imun-training-activity-history.json") ?? []
        trainingActivities = cloudTrainingActivities
        importedHealthRuns = read("apple-health-imported-runs.json") ?? []
        runHistory = importedHealthRuns
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
        confirmedScheduleDate = nil
        workout = nil
        runPlan = nil
        sendToWatch() // Prevent a different account's cached plan persisting on Watch.
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

    private func smartTargets(_ plan: HCWorkout, history: [HCPerformanceSet], preserveExisting: Bool) -> HCWorkout {
        let smartExercises = plan.exercises.map { exercise -> HCExercise in
            let target = HCProgressionEngine.suggest(exercise,
                history: history.filter { $0.date < plan.date },
                returning: plan.sessionKey.hasSuffix("SatUpper"))
            return HCExercise(id:exercise.id, name:exercise.name,
                originalName:exercise.originalName,exerciseIndex:exercise.exerciseIndex,
                prescribedSets:exercise.prescribedSets,repMin:exercise.repMin,repMax:exercise.repMax,
                suggestedWeightLb:preserveExisting
                    ? (exercise.suggestedWeightLb ?? target.weightLb)
                    : (target.weightLb ?? exercise.suggestedWeightLb),
                restSeconds:exercise.restSeconds)
        }
        return HCWorkout(id:plan.id,date:plan.date,sessionKey:plan.sessionKey,
                         title:plan.title,exercises:smartExercises,isPreview:false)
    }

    func refresh(date: Date) {
        guard signedIn else { status = "Sign in to load your plan."; return }
        let dateText = HCPlanBuilder.dateString(date)
        refreshGeneration += 1
        let generation = refreshGeneration
        loading = true
        status = "Refreshing workouts and training history…"
        Task {
            do {
                let snapshot = try await cloud.fetchPlannerAndHistory()
                // Progress always includes the entire recorded history, even
                // when the user browses an earlier date. Suggestions are date-
                // filtered separately in suggestion(for:on:).
                let futureBoundary = HCPlanBuilder.startOfDate("2099-01-01") ?? Date()
                let watchHistory = (try? await cloud.fetchWatchPerformance(before:"2099-01-01")) ?? []
                let history = HCPlanBuilder.performanceHistory(
                    from:snapshot.history,before:futureBoundary) + watchHistory
                let saved = try? await cloud.fetchPublishedPlan(date:dateText)
                let baseline = saved ?? HCPlanBuilder.workout(for:date,planner:snapshot.planner,
                                                              history:snapshot.history)
                let active = pendingEditedWorkout?.date == dateText
                    ? pendingEditedWorkout
                    : baseline.map { smartTargets($0,history:history,
                                                   preserveExisting:saved != nil) }
                let run = HCPlanBuilder.run(for:date,planner:snapshot.planner)
                let priorRuns = (try? await cloud.fetchRunHistory()) ?? []
                let recovery = (try? await cloud.fetchRecoveryHistory()) ?? []
                let activities = (try? await cloud.fetchActivityHistory()) ?? []

                DispatchQueue.main.async {
                    // Ignore stale/out-of-order responses and midnight rollovers.
                    guard generation == self.refreshGeneration else { return }
                    guard dateText == HCPlanBuilder.dateString(Date()) else {
                        self.loading = false
                        self.refresh(date: Date())
                        return
                    }
                    self.confirmedScheduleDate = dateText
                    self.workout = active
                    self.runPlan = run
                    self.plannedSessions = HCPlanBuilder.upcomingWithRotation(from: snapshot.planner)
                    self.cloudTrainingActivities = activities
                    self.mergeHistoricalSources()
                    self.save(self.plannedSessions, name: "imun-planned-workouts.json")
                    self.save(activities, name: "imun-training-activity-history.json")
                    self.saveOriginalSources(planner: snapshot.planner,
                                             history: snapshot.history,
                                             activities: activities, recovery: recovery)
                    if let archived = self.lastArchiveAt {
                        self.save(archived, name: "imun-source-archive-date.json")
                    }
                    self.performanceHistory = history
                    self.remoteRunHistory = priorRuns
                    self.mergeRunHistory()
                    self.cloudRecoveryHistory = recovery
                    self.mergeHistoricalSources()
                    self.loading = false
                    self.status = active == nil ? "No strength session on this date." :
                        "Workout ready: \(active!.title)"
                    self.sendToWatch()
                    self.retryPendingCloudSets()
                    self.retryPendingWorkout()
                }
            } catch {
                DispatchQueue.main.async {
                    guard generation == self.refreshGeneration else { return }
                    self.loading = false
                    self.status = "Unable to refresh: \(error.localizedDescription)"
                    self.retryPendingCloudSets()
                }
            }
        }
    }

    /// Lightweight calendar check for interactive Watch refresh and foreground
    /// polling. Unlike full refresh, this does not re-download all historical
    /// runs, recovery and recorded sets every minute.
    func refreshTodaySchedule() {
        guard signedIn, !loading, !scheduleRefreshing else { return }
        scheduleRefreshing = true
        let day = HCPlanBuilder.dateString(Date())
        Task {
            do {
                let snapshot = try await cloud.fetchPlannerAndHistory()
                let published = try? await cloud.fetchPublishedPlan(date: day)
                DispatchQueue.main.async {
                    self.scheduleRefreshing = false
                    guard day == HCPlanBuilder.dateString(Date()), !self.loading else { return }
                    let baseline = published ?? HCPlanBuilder.workout(
                        for: Date(), planner: snapshot.planner, history: snapshot.history)
                    self.workout = self.pendingEditedWorkout?.date == day
                        ? self.pendingEditedWorkout
                        : baseline.map { self.smartTargets($0,
                                                history: self.performanceHistory,
                                                preserveExisting: published != nil) }
                    self.runPlan = HCPlanBuilder.run(for: Date(), planner: snapshot.planner)
                    self.plannedSessions = HCPlanBuilder.upcomingWithRotation(from: snapshot.planner)
                    self.save(self.plannedSessions, name: "imun-planned-workouts.json")
                    self.confirmedScheduleDate = day
                    self.sendToWatch()
                }
            } catch {
                DispatchQueue.main.async {
                    self.scheduleRefreshing = false
                    self.status = "Calendar refresh failed; last confirmed plan preserved."
                }
            }
        }
    }

    /// Move a scheduled workout without asking the coach. The RPC updates the
    /// original Command Center calendar atomically for this signed-in user.
    func moveWorkout(_ entry: HCPlannedSession, to newDate: Date) {
        guard signedIn, movingWorkoutID == nil else {
            status = "Sign in or finish the current schedule change first."
            return
        }
        let day = HCPlanBuilder.dateString(newDate)
        if day == entry.date { return }
        movingWorkoutID = entry.id
        status = "Moving \(entry.title)…"
        Task {
            do {
                if entry.id.hasPrefix("rotation-") {
                    try await cloud.moveRotationWorkout(
                        originalDate: entry.originalDate ?? entry.date,
                        to: day, title: entry.title)
                } else {
                    try await cloud.movePlannedWorkout(id: entry.id, to: day)
                }
                DispatchQueue.main.async {
                    self.movingWorkoutID = nil
                    self.status = "Moved \(entry.title) to \(day)."
                    self.refresh(date: Date())
                }
            } catch {
                DispatchQueue.main.async {
                    self.movingWorkoutID = nil
                    self.status = "Move failed: \(error.localizedDescription)"
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
        if plan.date == HCPlanBuilder.dateString(Date()) { confirmedScheduleDate = plan.date }
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

    /// No private Tredict credential or raw data ever leaves the iPhone.
    /// Parsed measurements are combined with the other on-device histories.
    func updateTredictSnapshot(_ snapshot: HCTredictSnapshot) {
        tredictSnapshot = snapshot
        mergeHistoricalSources()
        mergeRunHistory()
        sendToWatch()
    }

    private func mergeHistoricalSources() {
        let all = tredictSnapshot.activities + cloudTrainingActivities
        var unique: [HCTrainingActivity] = []
        for entry in all.sorted(by: { $0.date > $1.date }) {
            let duplicate = unique.contains { other in
                if other.id == entry.id { return true }
                guard other.date == entry.date, other.kind == entry.kind else { return false }
                if let a = other.durationSeconds, let b = entry.durationSeconds,
                   abs(a - b) < 90 {
                    if let d1 = other.distanceMeters, let d2 = entry.distanceMeters {
                        return abs(d1 - d2) < 150
                    }
                    return other.title.caseInsensitiveCompare(entry.title) == .orderedSame
                }
                return false
            }
            if !duplicate { unique.append(entry) }
        }
        trainingActivities = unique

        // Retain independent sources on the same date. The Tredict Personal
        // API and Command Center can provide different fields or provenance;
        // an identical calendar day does not make their readings equivalent.
        var measurements = Set<String>()
        var combined: [HCRecoveryDatum] = []
        for reading in (tredictSnapshot.recovery + cloudRecoveryHistory)
            .sorted(by: { $0.date > $1.date }) {
            let key = reading.date + ":" + reading.source
            if measurements.insert(key).inserted {
                combined.append(reading)
            }
        }
        recoveryHistory = combined
    }

    /// A matching Apple Health workout marks the planned run complete in the
    /// native interface. Imports remain local (and visible offline).
    func updateHealthRuns(_ imported: [HCProgressRun]) {
        importedHealthRuns = imported
        save(imported, name: "apple-health-imported-runs.json")
        mergeRunHistory()
        if WCSession.isSupported(), WCSession.default.activationState == .activated,
           WCSession.default.isPaired, WCSession.default.isWatchAppInstalled {
            sendToWatch()
        }
    }

    private func mergeRunHistory() {
        let all = (importedHealthRuns + tredictSnapshot.runs + remoteRunHistory).sorted {
            ($0.startedAt ?? HCPlanBuilder.startOfDate($0.date) ?? .distantPast) >
            ($1.startedAt ?? HCPlanBuilder.startOfDate($1.date) ?? .distantPast)
        }
        var unique: [HCProgressRun] = []
        for candidate in all {
            let same = unique.contains { previous in
                guard previous.date == candidate.date else { return false }
                if previous.id == candidate.id { return true }
                if let first = previous.startedAt, let second = candidate.startedAt,
                   abs(first.timeIntervalSince(second)) < 180 {
                    return true
                }
                // Legacy/connected activity logs don't always include precise
                // start times; compare known distance AND duration together.
                if let pMeters = previous.distanceMeters, let cMeters = candidate.distanceMeters,
                   let pTime = previous.durationSeconds, let cTime = candidate.durationSeconds {
                    return abs(pMeters - cMeters) < 120 && abs(pTime - cTime) < 90
                }
                return false
            }
            if !same { unique.append(candidate) }
        }
        runHistory = unique
        if let plan = runPlan, !plan.isCompleted,
           unique.contains(where: { $0.date == plan.date }) {
            runPlan = HCRunPlan(id: plan.id, date: plan.date,
                                title: plan.title, notes: plan.notes,
                                targetDistanceMiles: plan.targetDistanceMiles,
                                isCompleted: true)
        }
    }

    /// No AI context is uploaded until a user explicitly taps Ask Coach.
    /// A Health/Recovery snapshot is transmitted only with the extra opt-in.
    func askIMUNCoach(question: String, shareRecovery: Bool) async throws -> String {
        let today = HCPlanBuilder.dateString(Date())
        var lines = ["Today: \(today)", "Source: IMUN training calendar and recorded workout history"]
        if let lift = workout, lift.date == today {
            lines.append("Planned weightlifting: \(lift.title), \(lift.exercises.count) exercises, \(lift.prescribedSetCount) sets")
        } else {
            lines.append("No strength workout scheduled today")
        }
        if let run = runPlan, run.date == today {
            lines.append("Planned run: \(run.title), goal \(run.targetDistanceMiles.map { String(format: "%.1f miles", $0) } ?? "unspecified")")
        } else {
            lines.append("No run scheduled today")
        }
        for entry in performanceHistory.prefix(10) {
            lines.append("Strength history: \(entry.date) \(entry.exercise) \(String(format: "%.1f", entry.weightLb)) lb x \(entry.reps)")
        }
        for run in runHistory.prefix(8) {
            lines.append("Run: \(run.date) \(run.title), \(run.distanceMeters.map {
                String(format: "%.2f mi", $0 / 1609.344)
            } ?? "distance unknown"), source \(run.source)")
        }
        if shareRecovery {
            for datum in recoveryHistory.prefix(12) {
                lines.append("Recovery \(datum.source) \(datum.date): HRV RMSSD \(datum.hrvMS.map {
                    String(format: "%.0f ms", $0)
                } ?? "missing"), sleep \(datum.sleepSeconds.map {
                    String(format: "%.1f h", $0 / 3600)
                } ?? "missing"), low HR \(datum.dailyLowHR.map {
                    String(format: "%.0f bpm", $0)
                } ?? "missing")")
            }
        }
        return try await cloud.askIMUNCoach(question: question,
                                            context: lines.joined(separator: "\n"),
                                            shareRecovery: shareRecovery)
    }

    /// Only one dated snapshot describes today's plan for BOTH devices.
    /// Never send a previously selected day's workout as today's Watch plan.
    private func watchContext() throws -> [String: Any] {
        let today = HCPlanBuilder.dateString(Date())
        let state = !signedIn ? "signedOut" :
            confirmedScheduleDate == today ? "ready" : "loading"
        let snapshot = HCWatchSchedule(
            date: today,
            workout: state == "ready" && workout?.date == today ? workout : nil,
            runPlan: state == "ready" && runPlan?.date == today ? runPlan : nil,
            generatedAt: Date(),
            state: state
        )
        var context: [String: Any] = [HCPayload.schedule: try encoder.encode(snapshot)]
        let prefs = UserDefaults.standard
        context[HCPayload.accentStyle] = prefs.string(forKey:"hcAccentStyle") ?? "crimson"
        context[HCPayload.weightIncrement] = prefs.object(forKey:"hcWeightIncrement") as? Double ?? 5.0
        context[HCPayload.restOverride] = prefs.integer(forKey:"hcRestOverrideSeconds")
        context[HCPayload.watchHaptics] = prefs.object(forKey:"hcWatchHaptics") as? Bool ?? true
        context["hcRunVoiceCues"] = prefs.object(forKey:"hcRunVoiceCues") as? Bool ?? false
        context["hcRunAutoLaps"] = prefs.object(forKey:"hcRunAutoLaps") as? Bool ?? true
        context["hcRunIntervals"] = prefs.object(forKey:"hcRunIntervals") as? Bool ?? false
        context["hcRunCueMinutes"] = prefs.object(forKey:"hcRunCueMinutes") as? Int ?? 5
        // Only compact summaries go to Watch; raw HR traces and GPS stay on phone.
        let summaries = runHistory.prefix(12).map { source -> HCProgressRun in
            var result = source
            result.heartRateTrace = []
            result.routePoints = []
            return result
        }
        context[HCPayload.runHistory] = try encoder.encode(summaries)
        return context
    }

    func sendToWatch() {
        guard WCSession.isSupported() else { return }
        let connection = WCSession.default
        guard connection.activationState == .activated,
              connection.isPaired, connection.isWatchAppInstalled else { return }
        do {
            try connection.updateApplicationContext(watchContext())
            status = "Today's iPhone schedule sent to Watch."
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

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard let kind = message[HCPayload.kind] as? String else {
            replyHandler([:]); return
        }
        if kind == HCPayload.requestSchedule {
            DispatchQueue.main.async {
                // A quick reply repairs the Watch UI; the cloud refresh that follows
                // sends a new application context if the schedule changed elsewhere.
                replyHandler((try? self.watchContext()) ?? [:])
                if self.signedIn && !self.loading { self.refreshTodaySchedule() }
            }
            return
        }
        // Interactive WatchConnectivity immediately mirrors recorded sets/runs
        // when reachable. transferUserInfo still backs up every item for offline use.
        if let payload = message[HCPayload.data] as? Data {
            switch kind {
            case HCPayload.loggedSet:
                if let item = try? decoder.decode(HCLoggedSet.self, from: payload) {
                    DispatchQueue.main.async {
                        self.acceptSet(item)
                        replyHandler(["saved": true])
                    }
                    return
                }
            case HCPayload.completedRun:
                if let item = try? decoder.decode(HCRunFinished.self, from: payload) {
                    DispatchQueue.main.async {
                        self.acceptRun(item)
                        replyHandler(["saved": true])
                    }
                    return
                }
            default: break
            }
        }
        replyHandler(["saved": false])
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
