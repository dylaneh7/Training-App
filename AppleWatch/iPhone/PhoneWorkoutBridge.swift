import Foundation
import Combine
import WatchConnectivity

/// Observable IMUN coordinator: today's workout, editable upcoming schedule,
/// historical training sources and WatchConnectivity queues.
final class PhoneWorkoutBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var workout: HCWorkout?
    @Published private(set) var runPlan: HCRunPlan?
    @Published private(set) var loggedSets: [HCLoggedSet] = []
    @Published private(set) var cloudRecordedSets: [HCLoggedSet] = []
    @Published private(set) var progressSyncStatus = "Progress saved locally"
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
    private var tredictScheduledRuns: [HCTredictPlannedRun] = []
    private var manuallyCompletedRunKeys = Set<String>()
    @Published private(set) var recoveryHistory: [HCRecoveryDatum] = []
    @Published private(set) var performanceHistory: [HCPerformanceSet] = []
    @Published private(set) var status = "Preparing Health Coach…"
    @Published private(set) var watchSyncStatus = "Waiting for Watch connection"
    @Published private(set) var watchConnectionDetails = "Connection not checked"
    @Published private(set) var designCloudStatus = "Appearance stored on iPhone"
    @Published private(set) var watchLastAcknowledgedAt: Date?
    private var sendAfterCalendarRefresh = false
    private var sendWhenWatchActivated = false
    // If the OS temporarily reports the companion missing, never throw away
    // the user's requested delivery. Re-check on pairing/reachability changes.
    private var watchDeliveryWaitingForRegistration = false
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
    private var fetchingProgress = false
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
        manuallyCompletedRunKeys = Set(read("imun-manually-completed-runs.json") ?? [String]())
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
                    self.runPlan = self.enrichedRunPlan(run)
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
                    self.refreshCloudProgress()
                    self.remoteRunHistory = priorRuns
                    self.mergeRunHistory()
                    self.cloudRecoveryHistory = recovery
                    self.mergeHistoricalSources()
                    self.loading = false
                    self.status = active == nil ? "No strength session on this date." :
                        "Workout ready: \(active!.title)"
                    let queueOnCompletion = self.sendAfterCalendarRefresh
                    self.sendAfterCalendarRefresh = false
                    self.sendToWatch(forceQueue: queueOnCompletion)
                    // Publish the same dated workout the iPhone shows. The
                    // Watch can fetch it securely from the user's account
                    // if Apple's companion registration stops working.
                    if saved == nil, let active, active.date == dateText {
                        Task { try? await self.cloud.saveWorkout(active) }
                    }
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
    func refreshTodaySchedule(forceWatchDelivery: Bool = false) {
        guard signedIn else {
            if forceWatchDelivery { watchSyncStatus = "Sign in to sync today's workout" }
            return
        }
        guard !loading, !scheduleRefreshing else {
            if forceWatchDelivery {
                sendAfterCalendarRefresh = true
                watchSyncStatus = "Finishing current workout refresh…"
            }
            return
        }
        scheduleRefreshing = true
        if forceWatchDelivery {
            watchSyncStatus = "Refreshing today's workout from Command Center…"
        }
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
                    self.runPlan = self.enrichedRunPlan(HCPlanBuilder.run(for: Date(), planner: snapshot.planner))
                    self.plannedSessions = HCPlanBuilder.upcomingWithRotation(from: snapshot.planner)
                    self.save(self.plannedSessions, name: "imun-planned-workouts.json")
                    self.confirmedScheduleDate = day
                    self.mergeRunHistory() // Preserve a completed run across calendar polls.
                    let manualDelivery = forceWatchDelivery || self.sendAfterCalendarRefresh
                    self.sendAfterCalendarRefresh = false
                    self.sendToWatch(forceQueue: manualDelivery)
                    self.refreshCloudProgress()
                    if published == nil, let ready = self.workout, ready.date == day {
                        Task { try? await self.cloud.saveWorkout(ready) }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.scheduleRefreshing = false
                    if forceWatchDelivery || self.sendAfterCalendarRefresh {
                        self.watchSyncStatus = "Couldn't refresh the training plan: " +
                            error.localizedDescription
                        self.sendAfterCalendarRefresh = false
                    }
                    self.status = "Calendar refresh failed; last confirmed plan preserved."
                }
            }
        }
    }

    /// Independent appearance sync: no WCSession availability check and no
    /// additional workout/schedule refresh. Existing Keychain credentials and
    /// the private user-owned cloud row provide the connection.
    func publishDesignToCloud() {
        guard signedIn else {
            designCloudStatus = "Sign in to sync appearance"
            return
        }
        let payload = IMUNStyle.cloudDesignPayload()
        designCloudStatus = "Saving appearance to cloud…"
        Task {
            do {
                try await cloud.saveVisualPreferences(payload)
                DispatchQueue.main.async {
                    self.designCloudStatus =
                        payload["watchSyncEnabled"] as? Bool == true
                        ? "Design shared · open iMun Watch to apply"
                        : "Watch sharing off · iPhone appearance kept"
                }
            } catch {
                DispatchQueue.main.async {
                    self.designCloudStatus =
                        "Could not sync appearance: " + error.localizedDescription
                }
            }
        }
    }

    func refreshAndSendToWatch() {
        guard signedIn else {
            watchSyncStatus = "Sign in to send your workout to Watch"
            return
        }
        refreshTodaySchedule(forceWatchDelivery: true)
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

    /// The iPhone's current running plan is the same plan sent to iMun Watch.
    /// Don't guess which workout to use if multiple Tredict programs overlap.
    func updateTredictScheduledRuns(_ runs: [HCTredictPlannedRun]) {
        tredictScheduledRuns = runs
        runPlan = enrichedRunPlan(runPlan)
        mergeRunHistory()
        if confirmedScheduleDate == HCPlanBuilder.dateString(Date()) { sendToWatch() }
    }

    private func relevantWords(_ title: String) -> Set<String> {
        let ignored: Set<String> = [
            "run", "running", "minutes", "minute", "min", "mins", "mile",
            "miles", "mi", "km", "mon", "tue", "wed", "thu", "fri", "sat", "sun",
            "today", "workout", "session"
        ]
        return Set(title.lowercased().split(whereSeparator: {
            !$0.isLetter && !$0.isNumber
        }).map(String.init).filter {
            !ignored.contains($0) && $0.range(of: #"^w\d+$"#,
                                                options: .regularExpression) == nil
        })
    }

    private func enrichedRunPlan(_ original: HCRunPlan?) -> HCRunPlan? {
        let today = HCPlanBuilder.dateString(Date())
        let candidates = tredictScheduledRuns.filter {
            $0.date == today && $0.unsupportedReason == nil && !$0.steps.isEmpty
        }
        let run: HCTredictPlannedRun?
        if let original {
            let words = relevantWords(original.title)
            let matching = candidates.filter {
                let other = relevantWords($0.title)
                return !words.isEmpty && words.isSubset(of: other)
            }
            run = matching.count == 1 ? matching.first : nil
        } else {
            // Never select one program arbitrarily when calendars overlap.
            run = candidates.count == 1 ? candidates.first : nil
        }
        guard let run else { return original }
        let steps = run.steps.map { item -> HCRunStep in
            let kind: String
            switch item.phase {
            case .warmup: kind = "warmup"
            case .work: kind = "work"
            case .recovery: kind = "recovery"
            case .cooldown: kind = "cooldown"
            }
            let seconds: Double?
            let distance: Double?
            switch item.duration {
            case .seconds(let value): seconds = value; distance = nil
            case .meters(let value): seconds = nil; distance = value
            case .open: seconds = nil; distance = nil
            }
            return HCRunStep(title: item.label, phase: kind, seconds: seconds,
                             distanceMeters: distance,
                             minBPM: item.heartRate?.lowerBound,
                             maxBPM: item.heartRate?.upperBound)
        }
        if var original {
            original.structuredSteps = steps
            return original
        }
        let distance = steps.compactMap(\.distanceMeters).reduce(0, +)
        return HCRunPlan(id: "tredict:" + run.id, date: run.date, title: run.title,
                         notes: run.notes, targetDistanceMiles: distance > 0
                         ? distance / 1609.344 : nil,
                         isCompleted: run.hasExecutedActivity, structuredSteps: steps)
    }

    /// Recorded HealthKit data is preferred. This explicit fallback tracks a
    /// user's reported completion without inventing sensor data or a fake run.
    func setRunManuallyCompleted(_ completed: Bool) {
        guard let plan = runPlan, plan.date == HCPlanBuilder.dateString(Date()) else { return }
        let key = plan.date + ":" + plan.id
        if completed { manuallyCompletedRunKeys.insert(key) }
        else { manuallyCompletedRunKeys.remove(key) }
        save(Array(manuallyCompletedRunKeys), name: "imun-manually-completed-runs.json")
        mergeRunHistory()
        sendToWatch()
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
        let localWatchRuns: [HCProgressRun] = completedWatchRuns.map { finished in
            var item = HCProgressRun(
                id: "imun-watch:" + finished.id.uuidString,
                date: finished.date, title: "iMun Watch Run",
                source: "iMun Watch", distanceMeters: finished.distanceMeters,
                durationSeconds: max(0, finished.endedAt.timeIntervalSince(finished.startedAt)),
                averageBPM: finished.averageHeartRate, splits: finished.splits)
            item.startedAt = finished.startedAt
            item.endedAt = finished.endedAt
            return item
        }
        let all = (importedHealthRuns + localWatchRuns + tredictSnapshot.runs + remoteRunHistory).sorted {
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
        if var plan = runPlan {
            let exactID = plan.date + ":" + plan.id
            let fromRun = unique.contains(where: { $0.date == plan.date })
            let fromWatch = completedWatchRuns.contains {
                $0.planID == plan.id && $0.date == plan.date
            }
            let done = plan.isCompleted || fromRun || fromWatch ||
                manuallyCompletedRunKeys.contains(exactID)
            if plan.isCompleted != done {
                plan = HCRunPlan(id: plan.id, date: plan.date,
                                 title: plan.title, notes: plan.notes,
                                 targetDistanceMiles: plan.targetDistanceMiles,
                                 isCompleted: done, structuredSteps: plan.structuredSteps)
                runPlan = plan
            }
        }
    }

    func checkCoachAIConnection() async -> String {
        do {
            return try await cloud.checkIMUNCoachAvailability()
        } catch {
            return "AI unavailable · " + error.localizedDescription
        }
    }

    /// No AI context is uploaded until a user explicitly taps Ask Coach.
    /// A Health/Recovery snapshot is transmitted only with the extra opt-in.
    func askIMUNCoach(question: String, shareRecovery: Bool,
                      recentConversation: String = "") async throws -> String {
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
        // Coach gets the same seven-day calendar shown on its home screen.
        // Include future workout details only when a signed-in athlete asks.
        let start = Calendar.current.startOfDay(for: Date())
        let comingDates = Set((0..<7).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: start)
                .map { HCPlanBuilder.dateString($0) }
        })
        let upcomingSessions = plannedSessions
            .filter { comingDates.contains($0.date) }
            .sorted { ($0.date, $0.title) < ($1.date, $1.title) }
        lines.append("Training calendar: next seven days starting \(today)")
        if upcomingSessions.isEmpty {
            lines.append("No next-week sessions found in the currently connected calendar")
        } else {
            for planned in upcomingSessions.prefix(21) {
                var summary = "\(planned.date): \(planned.kind) — \(planned.title)"
                summary += planned.completed ? " (completed)" : " (planned)"
                if !planned.notes.isEmpty {
                    summary += ". Notes: " + String(planned.notes.prefix(140))
                }
                lines.append(summary)
            }
        }
        for entry in performanceHistory.prefix(10) {
            lines.append("Strength history: \(entry.date) \(entry.exercise) \(String(format: "%.1f", entry.weightLb)) lb x \(entry.reps)")
        }
        for run in runHistory.prefix(8) {
            let distance = run.distanceMeters.map { String(format: "%.2f mi", $0 / 1609.344) }
                ?? "distance unknown"
            lines.append("Run: \(run.date) \(run.title), \(distance), source \(run.source)")
        }
        if shareRecovery {
            for datum in recoveryHistory.prefix(12) {
                let hrv = datum.hrvMS.map { String(format: "%.0f ms", $0) } ?? "missing"
                let sleep = datum.sleepSeconds.map { String(format: "%.1f h", $0 / 3600) }
                    ?? "missing"
                let hr = datum.dailyLowHR.map { String(format: "%.0f bpm", $0) } ?? "missing"
                lines.append("Recovery \(datum.source) \(datum.date): HRV RMSSD \(hrv), sleep \(sleep), low HR \(hr)")
            }
        }
        let prior = recentConversation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prior.isEmpty {
            // Keep history small and device-initiated. Nothing is uploaded while idle.
            lines.insert("Recent coach conversation (for continuity only): " +
                         String(prior.suffix(1000)), at: 1)
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
        // Appearance is optional and independent from schedule delivery.
        // Enabling it never changes or deletes workout records.
        if prefs.bool(forKey: "hcDesignWatchSyncEnabled") {
            context["imunDesignSyncV1"] = true
            let designKeys = [
                "hcDesignPreset", "hcDesignMode", "hcDesignCustomPalette",
                "hcDesignCustomGeometry", "hcDesignAccentHex",
                "hcDesignBackgroundHex", "hcDesignSurfaceHex",
                "hcDesignTextHex", "hcDesignShape", "hcDesignButtonShape",
                "hcDesignFont", "hcDesignDensity", "hcDesignMotif",
                "hcDesignNavigation", "hcDesignProgress",
                "hcDesignReduceMotion"
            ]
            for key in designKeys {
                if let value = prefs.object(forKey: key) {
                    context[key] = value
                }
            }
            context["hcDesignPreset"] = prefs.string(forKey:"hcDesignPreset") ?? "techno"
            context["hcDesignCustomPalette"] = prefs.bool(forKey:"hcDesignCustomPalette")
            context["hcDesignCustomGeometry"] = prefs.bool(forKey:"hcDesignCustomGeometry")
        }
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
        // Optional history must never prevent delivery of today's actual workout.
        // WCSession interactive messages also have tight payload size limits.
        if let history = try? encoder.encode(summaries), history.count < 40_000 {
            context[HCPayload.runHistory] = history
        }
        if let recent = recoveryHistory.first,
           let snapshot = try? encoder.encode(recent), snapshot.count < 16_000 {
            context["hcRecoverySnapshot"] = snapshot
        }
        return context
    }

    /// Report WatchConnectivity's actual state rather than assuming a Watch
    /// seen by Bluetooth or on the wrist is recognized as THIS app's companion.
    /// Call from Settings and from activation/watch-state callbacks.
    func checkWatchConnection() {
        guard WCSession.isSupported() else {
            watchConnectionDetails = "WatchConnectivity unavailable on this device"
            return
        }
        let connection = WCSession.default
        guard connection.activationState == .activated else {
            watchConnectionDetails = "Watch session is not activated"
            connection.activate()
            return
        }
        watchConnectionDetails =
            "Paired: " + (connection.isPaired ? "Yes" : "No") +
            " · iMun Watch installed: " + (connection.isWatchAppInstalled ? "Yes" : "No") +
            " · Live reachable: " + (connection.isReachable ? "Yes" : "No")
    }

    /// A context update is a *pending delivery*, not proof of Watch receipt.
    /// Live messages get a reply; manual sends fall back to a reliable background
    /// transfer. All forms carry the same date-scoped schedule snapshot.
    func sendToWatch(forceQueue: Bool = false) {
        guard WCSession.isSupported() else {
            watchSyncStatus = "Watch connectivity unavailable on this iPhone"
            return
        }
        let connection = WCSession.default
        guard connection.activationState == .activated else {
            sendWhenWatchActivated = true
            if forceQueue { sendAfterCalendarRefresh = true }
            watchSyncStatus = "Preparing the Watch connection…"
            connection.activate()
            return
        }
        checkWatchConnection()
        guard connection.isPaired else {
            watchSyncStatus = "No paired Apple Watch recognized by this iPhone"
            return
        }
        // Do not block the entire workout pipeline on a stale
        // isWatchAppInstalled value. On some developer installations the
        // iPhone reports false even when the physical Watch has the app.
        // Try the transport and handle the real result, not just this hint.
        let isRegistered = connection.isWatchAppInstalled
        if !isRegistered { watchDeliveryWaitingForRegistration = true }
        do {
            let current = try watchContext()
            var contextFailure: Error?
            do {
                try connection.updateApplicationContext(current)
            } catch {
                contextFailure = error
            }
            guard let scheduleBytes = current[HCPayload.schedule] as? Data,
                  let scheduled = try? decoder.decode(HCWatchSchedule.self,
                                                      from: scheduleBytes) else {
                watchSyncStatus = "Could not verify today's schedule payload"
                return
            }
            var packet = current
            packet[HCPayload.kind] = HCPayload.pushSchedule
            if let contextFailure {
                watchSyncStatus = "Watch context not delivered: " +
                    contextFailure.localizedDescription
                if forceQueue { queueWatchDelivery(packet) }
                return
            }
            if connection.isReachable {
                connection.sendMessage(packet, replyHandler: { [weak self] reply in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        let accepted = reply["received"] as? Bool == true &&
                            reply["scheduleState"] as? String == scheduled.state &&
                            reply["workoutID"] as? String == (scheduled.workout?.id ?? "")
                        if accepted {
                            self.watchLastAcknowledgedAt = Date()
                            if scheduled.state != "ready" {
                                self.watchSyncStatus = "Watch connected · waiting for today's workout"
                            } else if let lift = scheduled.workout {
                                self.watchSyncStatus = "Watch loaded: " + lift.title
                            } else {
                                self.watchSyncStatus = "Watch confirmed no lift scheduled today"
                            }
                        } else if forceQueue {
                            self.queueWatchDelivery(packet)
                        } else {
                            self.watchSyncStatus = "Watch did not confirm the workout · Refresh & send again"
                        }
                    }
                }, errorHandler: { [weak self] error in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        if forceQueue {
                            self.queueWatchDelivery(packet)
                        } else {
                            self.watchSyncStatus = "Saved for Watch: " + error.localizedDescription
                        }
                    }
                })
                watchSyncStatus = "Sending today's plan to Watch…"
            } else if forceQueue {
                queueWatchDelivery(packet)
            } else if !isRegistered {
                watchSyncStatus = "Workout prepared · waiting for watchOS to recognize iMun"
            } else {
                watchSyncStatus = "Plan ready · waiting for Watch to connect"
            }
        } catch {
            watchSyncStatus = "Couldn't prepare Watch sync: " + error.localizedDescription
        }
    }

    private func queueWatchDelivery(_ packet: [String: Any]) {
        let connection = WCSession.default
        guard connection.activationState == .activated else { return }
        // A manual queue is used only on demand; regular calendar polling
        // uses replaceable application context instead of accumulating events.
        let hasIdenticalPending = connection.outstandingUserInfoTransfers.contains {
            transfer in
            guard (transfer.userInfo[HCPayload.kind] as? String) == HCPayload.pushSchedule,
                  let queued = transfer.userInfo[HCPayload.schedule] as? Data,
                  let next = packet[HCPayload.schedule] as? Data else { return false }
            return queued == next
        }
        if !hasIdenticalPending { connection.transferUserInfo(packet) }
        watchSyncStatus = connection.isWatchAppInstalled
            ? "Workout queued for Watch · awaiting confirmation"
            : "Workout queued · watchOS has not recognized the companion yet"
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

    /// All raw device records remain available for corrections and exports,
    /// but only one dated prescribed set slot counts toward progress.
    var combinedRecordedSets: [HCLoggedSet] {
        HCSetReconciliation.allRecords(local: loggedSets, cloud: cloudRecordedSets)
    }

    func completedSets(for plan: HCWorkout) -> [HCLoggedSet] {
        HCSetReconciliation.completed(for: plan, records: combinedRecordedSets)
    }

    func refreshCloudProgress() {
        guard signedIn, !fetchingProgress,
              let requested = workout,
              requested.date == HCPlanBuilder.dateString(Date()) else { return }
        fetchingProgress = true
        Task {
            do {
                let entries = try await cloud.fetchCompletedSets(for: requested)
                DispatchQueue.main.async {
                    self.fetchingProgress = false
                    guard self.workout?.id == requested.id else { return }
                    self.cloudRecordedSets = entries
                    self.progressSyncStatus = "Phone and Watch progress synced"
                }
            } catch {
                DispatchQueue.main.async {
                    self.fetchingProgress = false
                    self.progressSyncStatus = "Offline progress retained: " +
                        error.localizedDescription
                }
            }
        }
    }

    func logFromPhone(exercise: HCExercise, weightLb: Double?, reps: Int, rir: Double?) {
        guard let workout, reps > 0, reps <= 300,
              weightLb == nil || (weightLb! >= 0 && weightLb! <= 3000) else { return }
        let next = HCSetReconciliation.nextSetIndex(
            for: exercise, workout: workout, records: combinedRecordedSets)
        var entry = HCLoggedSet(id:UUID(),workoutID:workout.id,workoutDate:workout.date,
                                sessionKey:workout.sessionKey,workoutTitle:workout.title,
                                exerciseID:exercise.id,exerciseName:exercise.name,
                                exerciseIndex:exercise.exerciseIndex,index:next,
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
        refreshCloudProgress()
    }

    private func acceptRun(_ entry: HCRunFinished) {
        guard !completedWatchRuns.contains(where:{$0.id == entry.id}) else { return }
        completedWatchRuns.append(entry)
        save(completedWatchRuns,name:"health-coach-native-runs.json")
        updatePendingCount()
        status = "Run saved locally"
        mergeRunHistory()
        sendToWatch()
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
                self.refreshCloudProgress()
                self.status = errorMessage.map {
                    "Saved offline. Sync will retry: \($0)"
                } ?? "Workout data synced"
            }
        }
    }

    private func confirmWatchRecord(_ id: UUID) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isPaired else { return }
        WCSession.default.transferUserInfo([
            HCPayload.kind: HCPayload.syncReceipt,
            "recordID": id.uuidString
        ])
    }

    // MARK: - Watch Connectivity

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if state == .activated {
                self.checkWatchConnection()
                let queuePending = self.sendAfterCalendarRefresh
                self.sendAfterCalendarRefresh = false
                self.sendWhenWatchActivated = false
                self.sendToWatch(forceQueue: queuePending)
                if self.signedIn && self.confirmedScheduleDate != HCPlanBuilder.dateString(Date()) {
                    self.refreshTodaySchedule(forceWatchDelivery: queuePending)
                }
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
        if kind == "imunDiagnosticPingV1" {
            replyHandler(["imunDiagnosticPong": true])
            return
        }
        if kind == HCPayload.requestSchedule {
            DispatchQueue.main.async {
                // Reply promptly with the last confirmed date-scoped snapshot,
                // then push a *fresh* cloud result as soon as it loads.
                var reply = (try? self.watchContext()) ?? [:]
                reply["refreshing"] = self.signedIn
                replyHandler(reply)
                if self.signedIn {
                    self.refreshTodaySchedule(forceWatchDelivery:
                        message["forceRefresh"] as? Bool ?? false)
                }
            }
            return
        }
        if kind == HCPayload.syncRequest {
            DispatchQueue.main.async {
                self.retryPendingCloudSets()
                replyHandler(["saved": true])
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

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.checkWatchConnection()
            guard session.activationState == .activated,
                  session.isPaired, session.isWatchAppInstalled,
                  self.watchDeliveryWaitingForRegistration else { return }
            self.watchDeliveryWaitingForRegistration = false
            // Registration is finally visible: resend the current dated plan,
            // even if the user is no longer looking at the Connections page.
            self.refreshTodaySchedule(forceWatchDelivery: true)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.checkWatchConnection()
            if session.activationState == .activated, session.isReachable,
               self.signedIn, self.confirmedScheduleDate == HCPlanBuilder.dateString(Date()) {
                self.sendToWatch(forceQueue: false)
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession,
                 didFinish userInfoTransfer: WCSessionUserInfoTransfer,
                 error: Error?) {
        guard userInfoTransfer.userInfo[HCPayload.kind] as? String == HCPayload.pushSchedule else {
            return
        }
        DispatchQueue.main.async {
            if let error {
                self.watchSyncStatus = "Watch delivery failed: " + error.localizedDescription
            } else {
                // A completed background transfer is not a loaded-workout
                // acknowledgment. The Watch separately sends a scheduleReceipt.
                self.watchSyncStatus = "Workout transferred · awaiting Watch confirmation"
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if userInfo[HCPayload.kind] as? String == HCPayload.requestSchedule {
            DispatchQueue.main.async {
                self.refreshTodaySchedule(forceWatchDelivery: true)
            }
            return
        }
        if userInfo[HCPayload.kind] as? String == HCPayload.scheduleReceipt {
            DispatchQueue.main.async {
                let today = HCPlanBuilder.dateString(Date())
                guard userInfo["date"] as? String == today,
                      self.confirmedScheduleDate == today,
                      userInfo["scheduleState"] as? String == "ready",
                      userInfo["workoutID"] as? String ==
                          (self.workout?.date == today ? self.workout?.id ?? "" : "") else { return }
                self.watchLastAcknowledgedAt = Date()
                self.watchSyncStatus = self.workout.map {
                    "Watch loaded: " + $0.title
                } ?? "Watch confirmed no lift scheduled today"
            }
            return
        }
        guard let kind = userInfo[HCPayload.kind] as? String,
              let payload = userInfo[HCPayload.data] as? Data else { return }
        switch kind {
        case HCPayload.loggedSet:
            guard let item = try? decoder.decode(HCLoggedSet.self,from:payload) else { return }
            DispatchQueue.main.async {
                self.acceptSet(item)
                self.confirmWatchRecord(item.id)
            }
        case HCPayload.completedRun:
            guard let item = try? decoder.decode(HCRunFinished.self,from:payload) else { return }
            DispatchQueue.main.async {
                self.acceptRun(item)
                self.confirmWatchRecord(item.id)
            }
        default: break
        }
    }
}
