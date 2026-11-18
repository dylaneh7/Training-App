import Foundation
import Combine
import WatchConnectivity
import Security

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
    // Optional for backward-compatible clocks recorded before guided set picking.
    var setNumber: Int? = nil
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

struct HCGuidedSetChoice: Codable, Equatable {
    let exerciseID: String
    let setNumber: Int
}

final class WatchWorkoutStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var workout: HCWorkout = .unscheduled(date: WatchWorkoutStore.today())
    @Published private(set) var scheduleState = "loading"
    @Published private(set) var scheduleUpdatedAt: Date?
    @Published private(set) var hasScheduledLift = false
    @Published private(set) var runPlan: HCRunPlan?
    @Published private(set) var runHistory: [HCProgressRun] = []
    @Published private(set) var recoverySummary: HCRecoveryDatum?
    @Published private(set) var eitanSnapshot: HCEitanSnapshot?
    @Published private(set) var eitanSyncStatus = "Waiting for iPhone EITAN sync"
    @Published private(set) var eitanLastReceivedAt: Date?
    @Published private(set) var eitanTransportDetails = "No EITAN packet from iPhone yet"
    @Published private(set) var eitanPhoneBuild = "Not connected"
    @Published private(set) var eitanCloudStatus =
        "Private cloud EITAN has not been checked"
    @Published private(set) var eitanCloudReceivedAt: Date?
    private var checkingEitanCloud = false
    private var lastEitanCloudCheck = Date.distantPast
    private var lastEitanLiveRequestAt = Date.distantPast
    @Published private(set) var sets: [HCLoggedSet] = []
    // Preserve all original records locally; cloud history is read-only.
    @Published private(set) var cloudSets: [HCLoggedSet] = []
    @Published private(set) var undoRecords: [HCWorkoutUndo] = []
    @Published private(set) var cloudUndoRecords: [HCWorkoutUndo] = []
    @Published private(set) var progressSyncStatus = "Cloud progress not checked"
    @Published private(set) var completedRuns: [HCRunFinished] = []
    @Published private(set) var liftClock: HCTrainingClock?
    @Published private(set) var guidedExerciseID: String?
    @Published private(set) var selectedGuidedSet: HCGuidedSetChoice?
    @Published private(set) var queuedNextGuidedSet: HCGuidedSetChoice?
    @Published private(set) var runClock: HCTrainingClock?
    @Published private(set) var status = "Ready to train"
    @Published private(set) var phoneConnectionStatus = "iPhone connection not checked"
    @Published private(set) var phonePingStatus = "No live connection test performed"
    @Published private(set) var cloudSignedIn = false
    @Published private(set) var cloudStatus = "Cloud fallback not connected"
    @Published private(set) var designCloudStatus = "Watch uses its local appearance"
    @Published private(set) var isRequestingSchedule = false
    @Published private(set) var lastPhoneAcknowledgement: Date?
    private var pendingManualScheduleRequest = false
    @Published private(set) var lastBackgroundTransfer = "No background Watch transfer result yet"
    private var lastLiftStateSignature: String?
    private var lastAutomaticResendAt = Date.distantPast

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var queuedIDs: Set<UUID> = []
    private var confirmedIDs: Set<UUID> = []
    private var latestSchedule: HCWatchSchedule?
    private var hasReceivedPhoneScheduleToday = false
    private var loadingCloudSchedule = false
    private var latestFullCloudScheduleAt: Date?
    private var latestAppliedPhoneScheduleAt: Date?
    private let cloud = HCWatchCloudFallback()

    /// Two independent routes, reported separately. A missing Apple
    /// companion registration is not a cloud failure or lost workout.
    var syncPathSummary: String {
        let direct = WCSession.isSupported() &&
            WCSession.default.activationState == .activated &&
            WCSession.default.isReachable
        return "Live iPhone: " + (direct ? "available" : "unavailable") +
            " · Cloud account: " + (cloudSignedIn ? "connected" : "signed out")
    }
    private var cloudUploadedIDs: Set<UUID> = []
    private var uploadedUndoIDs: Set<UUID> = []
    private var isUploadingCloudSets = false
    private var isFetchingCloudSets = false
    private var isFetchingCloudAppearance = false
    private var lastCloudAppearanceCheck = Date.distantPast

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
        if let s: [HCWorkoutUndo] = load("workout-undos.json") { undoRecords = s }
        if let s: [UUID] = load("uploaded-undo-ids.json") {
            uploadedUndoIDs = Set(s)
        }
        if let s: [UUID] = load("queued-ids.json") { queuedIDs = Set(s) }
        if let s: [UUID] = load("confirmed-ids.json") { confirmedIDs = Set(s) }
        if let s: [UUID] = load("cloud-uploaded-ids.json") { cloudUploadedIDs = Set(s) }
        if let s: HCTrainingClock = load("lifting-clock.json") { liftClock = s }
        guidedExerciseID = load("guided-exercise-id.json")
        selectedGuidedSet = load("guided-set-selection.json")
        queuedNextGuidedSet = load("queued-guided-set.json")
        if let s: HCTrainingClock = load("running-clock.json") { runClock = s }
        if let s: HCRunPlan = load("run-plan.json"), s.date == Self.today() { runPlan = s }
        if let s: [HCProgressRun] = load("run-history.json") { runHistory = s }
        if let s: [HCRunFinished] = load("completed-runs.json") { completedRuns = s }
        if let saved: HCEitanSnapshot = load("eitan-snapshot.json"),
           saved.date == Self.today(),
           (UserDefaults.standard.object(forKey: "hcEitanUseHealth") as? Bool ?? true) {
            eitanSnapshot = saved
            eitanSyncStatus = "Showing last synced iPhone EITAN"
        }

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            applyContext(WCSession.default.receivedApplicationContext)
            requestCurrentSchedule()
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let available = await cloud.hasSession()
            DispatchQueue.main.async {
                self.cloudSignedIn = available
                if available {
                    self.refreshCloudWorkout()
                    self.refreshCloudAppearance(force: true)
                    self.refreshCloudEitan(force: true)
                    self.uploadPendingCloudSets()
                }
            }
        }
    }

    /// One-time Watch login gives workouts a route that does not depend on
    /// Apple's companion-registration state. Tokens stay in Watch Keychain.
    func signInToCloud(email: String, password: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, !password.isEmpty else {
            cloudStatus = "Enter your Command Center email and password."
            return
        }
        cloudStatus = "Signing in securely…"
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await cloud.signIn(email: cleanEmail, password: password)
                DispatchQueue.main.async {
                    self.cloudSignedIn = true
                    self.cloudStatus = "Signed in · loading today's workout"
                    self.refreshCloudWorkout()
                    self.refreshCloudAppearance(force: true)
                    self.refreshCloudEitan(force: true)
                    self.uploadPendingCloudSets()
                }
            } catch {
                DispatchQueue.main.async {
                    self.cloudStatus = "Cloud sign-in failed: " + error.localizedDescription
                }
            }
        }
    }

    /// Fetch today's EITAN through the athlete's already authenticated
    /// account, with no dependency on isReachable, paired-app registration,
    /// or a background WatchConnectivity session.
    func refreshCloudEitan(force: Bool = false) {
        guard cloudSignedIn else {
            eitanCloudStatus =
                "Sign in to iMun cloud on Watch to sync EITAN without the iPhone link"
            return
        }
        guard !checkingEitanCloud,
              force || Date().timeIntervalSince(lastEitanCloudCheck) > 45
        else { return }
        checkingEitanCloud = true
        lastEitanCloudCheck = Date()
        eitanCloudStatus = "Checking private cloud for today's EITAN…"
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let row = try await cloud.fetchEitanForWatch()
                self.checkingEitanCloud = false
                guard let row else {
                    self.eitanCloudStatus =
                        "No private EITAN published. Enable EITAN cloud sync in iPhone Settings."
                    return
                }
                guard row.enabled else {
                    self.eitanCloudStatus =
                        "Private EITAN cloud sync is off on iPhone; no health data stored."
                    return
                }
                guard let snapshot = row.snapshot else {
                    self.eitanCloudStatus =
                        "Private cloud connected; iPhone has not calculated an EITAN score yet."
                    return
                }
                guard snapshot.date == Self.today() else {
                    self.eitanCloudStatus =
                        "Cloud has an earlier EITAN day; open iMun on iPhone to refresh."
                    return
                }
                let lastLocalRevision = UserDefaults.standard.double(
                    forKey: "hcEitanReceivedTimestamp")
                // Avoid overriding a newer WatchConnectivity revision with
                // an older, cached cloud row.
                if let updated = row.updatedAt,
                   updated.timeIntervalSince1970 + 1 < lastLocalRevision,
                   self.eitanSnapshot?.date == Self.today() {
                    self.eitanCloudStatus =
                        "Watch already has a newer EITAN snapshot than private cloud."
                    return
                }
                // This cloud row was uploaded only after the athlete
                // enabled Health-based EITAN and private Watch sync on iPhone.
                // Reconcile Watch's old preference cache so the received
                // wellness score is actually visible on the opening tile.
                UserDefaults.standard.set(true, forKey: "hcEitanEnabled")
                UserDefaults.standard.set(true, forKey: "hcEitanUseHealth")
                self.eitanSnapshot = snapshot
                self.save(snapshot, name: "eitan-snapshot.json")
                self.eitanCloudReceivedAt = Date()
                self.eitanLastReceivedAt = Date()
                self.eitanSyncStatus = snapshot.value == nil ?
                    "EITAN received via private cloud · personal baseline incomplete" :
                    "EITAN received via private cloud · phone link not needed"
                self.eitanTransportDetails =
                    "Private iMun cloud · owner account · source " +
                    (snapshot.primaryWearable ?? "Auto")
                self.eitanPhoneBuild = "Private cloud"
                self.eitanCloudStatus = snapshot.value.map {
                    "Private cloud EITAN synced: \($0)/100"
                } ?? "EITAN synced via cloud · waiting for enough Health data"
            } catch {
                self.checkingEitanCloud = false
                self.eitanCloudStatus =
                    "EITAN cloud fetch failed: " + error.localizedDescription
            }
        }
    }

    func refreshCloudWorkout() {
        guard cloudSignedIn else {
            cloudStatus = "Sign in to iMun cloud on Watch to load the workout"
            return
        }
        guard !loadingCloudSchedule else { return }
        loadingCloudSchedule = true
        let day = Self.today()
        cloudStatus = "Downloading today's strength and running plans…"
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                // New complete plan (includes no-lift days with scheduled runs).
                // An older strength-only row remains a compatibility fallback.
                let complete = try await cloud.fetchPublishedSchedule(date: day)
                let legacy = complete == nil
                    ? try await cloud.fetchPublishedWorkout(date: day) : nil
                DispatchQueue.main.async {
                    self.loadingCloudSchedule = false
                    guard day == Self.today() else { return }
                    // Accept a newer published cloud plan even if the Watch
                    // previously received an older plan through the iPhone.
                    // Live reachability is not required for freshness.
                    let newerThanPhone = complete.map {
                        $0.generatedAt > (self.latestAppliedPhoneScheduleAt ?? .distantPast)
                    } ?? false
                    if self.hasReceivedPhoneScheduleToday && !newerThanPhone {
                        self.cloudStatus = "Phone plan already current · cloud available as backup"
                        self.refreshCloudSets()
                        return
                    }
                    if let complete {
                        self.applySchedule(complete, fromFullCloud: true)
                        self.cloudStatus = complete.runPlan != nil
                            ? "Cloud running and strength plan loaded"
                            : "Cloud training schedule loaded"
                        self.refreshCloudSets()
                    } else if let legacy {
                        self.applySchedule(HCWatchSchedule(
                            date: day, workout: legacy,
                            runPlan: self.runPlan?.date == day ? self.runPlan : nil,
                            generatedAt: Date(), state: "ready"))
                        self.cloudStatus = "Legacy strength workout loaded · iPhone has not published a full plan"
                        self.refreshCloudSets()
                    } else {
                        self.cloudStatus = "No schedule published for today · open iMun on iPhone"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingCloudSchedule = false
                    self.cloudStatus = "Cloud schedule download failed: " + error.localizedDescription
                }
            }
        }
    }

    /// Uses the SAME authenticated cloud session as direct Watch workout
    /// recovery. This is optional; locally selected Watch themes always win
    /// when the athlete disables "Use iPhone style" in Preferences.
    func refreshCloudAppearance(force: Bool = false) {
        guard cloudSignedIn else {
            designCloudStatus = "Sign in on Watch to sync appearance"
            return
        }
        guard UserDefaults.standard.object(
            forKey: "hcDesignAcceptPhoneAppearance") as? Bool ?? true else {
            designCloudStatus = "Your Watch uses its own theme"
            return
        }
        guard !isFetchingCloudAppearance,
              force || Date().timeIntervalSince(lastCloudAppearanceCheck) > 60
        else { return }
        isFetchingCloudAppearance = true
        lastCloudAppearanceCheck = Date()
        designCloudStatus = "Checking cloud appearance…"
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let value = try await cloud.fetchVisualPreferences()
                DispatchQueue.main.async {
                    self.isFetchingCloudAppearance = false
                    guard UserDefaults.standard.object(
                        forKey: "hcDesignAcceptPhoneAppearance") as? Bool ?? true
                    else { return }
                    if let value, IMUNStyle.applyCloudDesign(value) {
                        self.designCloudStatus = "iPhone design applied through cloud"
                    } else {
                        self.designCloudStatus = "Using local Watch appearance"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isFetchingCloudAppearance = false
                    self.designCloudStatus =
                        "Could not fetch appearance: " + error.localizedDescription
                }
            }
        }
    }

    /// Read completed sets for this date and session from the authenticated
    /// cloud, independent of the phone connection. Never import them into the
    /// Watch's upload queue or overwrite local workout history.
    func refreshCloudSets() {
        guard cloudSignedIn, hasScheduledLift, workout.date == Self.today(),
              !isFetchingCloudSets else { return }
        let requested = workout
        isFetchingCloudSets = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let undoEntries = try await cloud.fetchWorkoutUndos(for: requested)
                let entries = try await cloud.fetchCompletedSets(for: requested)
                DispatchQueue.main.async {
                    self.isFetchingCloudSets = false
                    guard self.workout.id == requested.id,
                          self.workout.date == requested.date else { return }
                    let changed = Set(self.cloudUndoRecords) != Set(undoEntries) ||
                                  Set(self.cloudSets) != Set(entries)
                    if Set(self.cloudUndoRecords) != Set(undoEntries) {
                        self.cloudUndoRecords = undoEntries
                    }
                    if Set(self.cloudSets) != Set(entries) {
                        self.cloudSets = entries
                    }
                    if changed {
                        self.progressSyncStatus = "Workout changes received from cloud"
                    } else if self.progressSyncStatus.hasPrefix("Cloud progress not checked") {
                        self.progressSyncStatus = "Cloud workout progress connected"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isFetchingCloudSets = false
                    self.progressSyncStatus = "Offline progress retained: " +
                        error.localizedDescription
                }
            }
        }
    }

    /// Uploads retain stable UUIDs. The local set log is never removed, and
    /// a failed request simply remains pending for the next sync.
    func uploadPendingCloudSets() {
        guard cloudSignedIn, !isUploadingCloudSets else { return }
        let pendingUndo = undoRecords.filter { !uploadedUndoIDs.contains($0.id) }
        let pending = sets.filter { item in
            !cloudUploadedIDs.contains(item.id) &&
            !allUndoRecords.contains(where: { $0.applies(to: item) })
        }
        guard !pendingUndo.isEmpty || !pending.isEmpty else { return }
        isUploadingCloudSets = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            var failed = false
            var uploadedAny = false
            for undo in pendingUndo {
                do {
                    try await cloud.recordWorkoutUndo(undo)
                    uploadedAny = true
                    DispatchQueue.main.async {
                        self.uploadedUndoIDs.insert(undo.id)
                        self.save(Array(self.uploadedUndoIDs),
                                  name: "uploaded-undo-ids.json")
                        self.cloudStatus = "Workout correction synced"
                    }
                } catch {
                    failed = true
                    DispatchQueue.main.async {
                        self.cloudStatus = "Undo retained offline · retry: " +
                            error.localizedDescription
                    }
                    break
                }
            }
            if !failed {
                for entry in pending {
                    do {
                        try await cloud.upload(entry)
                        uploadedAny = true
                        DispatchQueue.main.async {
                            self.cloudUploadedIDs.insert(entry.id)
                            self.save(Array(self.cloudUploadedIDs),
                                      name: "cloud-uploaded-ids.json")
                            self.cloudStatus = "Logged sets saved to your account"
                        }
                    } catch {
                        failed = true
                        DispatchQueue.main.async {
                            self.cloudStatus = "Sets saved offline; cloud retry: " +
                                error.localizedDescription
                        }
                        break
                    }
                }
            }
            let cloudChanged = uploadedAny
            DispatchQueue.main.async {
                self.isUploadingCloudSets = false
                if cloudChanged { self.notifyPhoneCloudProgressChanged() }
                self.refreshCloudSets()
                // A correction can arrive while the previous upload is
                // active. Process it immediately after a successful batch.
                if !failed && self.undoRecords.contains(where: {
                    !self.uploadedUndoIDs.contains($0.id)
                }) {
                    self.uploadPendingCloudSets()
                }
            }
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

    var allUndoRecords: [HCWorkoutUndo] {
        HCWorkoutUndo.merged(local: undoRecords, cloud: cloudUndoRecords)
    }

    var allRecordedSets: [HCLoggedSet] {
        HCSetReconciliation.allRecords(local: sets, cloud: cloudSets,
                                      undos: allUndoRecords)
    }

    func completedSets(for exercise: HCExercise) -> [HCLoggedSet] {
        HCSetReconciliation.completed(for: workout, records: allRecordedSets)
            .filter { $0.exerciseID == exercise.id }
    }

    var lastUndoableSet: HCLoggedSet? {
        HCSetReconciliation.completed(for: workout, records: allRecordedSets)
            .max(by: { $0.completedAt < $1.completedAt })
    }

    /// Undo the last logged set. A corrected workout remains available and
    /// the DB blocks retransmitted stale records from either device.
    func undoSet(_ id: UUID) {
        guard let entry = allRecordedSets.first(where: { $0.id == id }),
              !allUndoRecords.contains(where: { $0.applies(to: entry) })
        else { return }
        appendUndo(HCWorkoutUndo.set(entry), forwardToPhone: true)
        if var clock = liftClock, clock.isActive, clock.setStartedAt == nil {
            // Return to the corrected set rather than remaining on a later
            // queued set or an unrelated rest countdown.
            clock.restEndsAt = nil
            liftClock = clock
            save(clock, name: "lifting-clock.json")
            let choice = HCGuidedSetChoice(exerciseID: entry.exerciseID,
                                          setNumber: entry.index)
            selectedGuidedSet = choice
            guidedExerciseID = entry.exerciseID
            queuedNextGuidedSet = nil
            save(choice, name: "guided-set-selection.json")
            save(entry.exerciseID, name: "guided-exercise-id.json")
            try? FileManager.default.removeItem(
                at: directory.appendingPathComponent("queued-guided-set.json"))
        }
        status = "Set undone · sync pending"
    }

    func undoLifting() {
        guard let clock = liftClock, clock.isActive,
              workout.id == clock.workoutID else { return }
        let undo = HCWorkoutUndo.workout(workout, startedAt: clock.startedAt)
        liftClock = nil
        selectedGuidedSet = nil
        queuedNextGuidedSet = nil
        guidedExerciseID = workout.exercises.first?.id
        if let first = guidedExerciseID {
            save(first, name: "guided-exercise-id.json")
        }
        for file in ["lifting-clock.json", "guided-set-selection.json",
                     "queued-guided-set.json"] {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
        appendUndo(undo, forwardToPhone: true)
        publishLiftSessionStatus(startedAt: clock.startedAt, active: false)
        status = "Workout undone. Ready to start again."
    }

    /// An in-progress run can be undone before it is saved to Apple Fitness
    /// or uploaded; a completed historical run is not silently deleted.
    func undoRun() {
        guard let clock = runClock, clock.isActive else { return }
        runClock = nil
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("running-clock.json"))
        status = "Run undone. Ready to start again."
    }

    private func appendUndo(_ undo: HCWorkoutUndo, forwardToPhone: Bool) {
        guard !undoRecords.contains(where: { $0.id == undo.id }) else { return }
        undoRecords.append(undo)
        save(undoRecords, name: "workout-undos.json")
        if forwardToPhone, WCSession.isSupported(),
           WCSession.default.activationState == .activated,
           let data = try? encoder.encode(undo) {
            let packet: [String: Any] = [
                HCPayload.kind: HCPayload.workoutUndo, HCPayload.data: data
            ]
            WCSession.default.transferUserInfo(packet)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(packet,
                    replyHandler: { [weak self] reply in
                        guard reply["saved"] as? Bool == true else { return }
                        DispatchQueue.main.async {
                            self?.markConfirmed(undo.id)
                        }
                    }, errorHandler: { _ in })
            }
            queuedIDs.insert(undo.id)
            save(Array(queuedIDs), name: "queued-ids.json")
        }
        uploadPendingCloudSets()
        refreshCloudSets()
    }

    // MARK: - One-screen, set-by-set strength workflow

    func completedSets(for exercise: HCExercise, setNumber: Int) -> Bool {
        completedSets(for: exercise).contains(where: { $0.index == setNumber })
    }

    private func firstUnfinishedSet(in exercise: HCExercise) -> Int? {
        guard exercise.prescribedSets > 0 else { return nil }
        return (1...exercise.prescribedSets).first {
            !completedSets(for: exercise, setNumber: $0)
        }
    }

    private func validChoice(_ choice: HCGuidedSetChoice?) -> HCGuidedSetChoice? {
        guard let choice,
              let exercise = workout.exercises.first(where: { $0.id == choice.exerciseID }),
              choice.setNumber >= 1, choice.setNumber <= exercise.prescribedSets,
              !completedSets(for: exercise, setNumber: choice.setNumber) else { return nil }
        return choice
    }

    private func recommendedChoice(after exerciseID: String? = nil) -> HCGuidedSetChoice? {
        if let exerciseID,
           let same = workout.exercises.first(where: { $0.id == exerciseID }),
           let number = firstUnfinishedSet(in: same) {
            return HCGuidedSetChoice(exerciseID: same.id, setNumber: number)
        }
        guard !workout.exercises.isEmpty else { return nil }
        let start = workout.exercises.firstIndex(where: { $0.id == exerciseID }) ?? -1
        for offset in 1...workout.exercises.count {
            let item = workout.exercises[
                (start + offset + workout.exercises.count) % workout.exercises.count
            ]
            if let number = firstUnfinishedSet(in: item) {
                return HCGuidedSetChoice(exerciseID: item.id, setNumber: number)
            }
        }
        return nil
    }

    /// An exercise may be chosen out of order. Every prescribed set number stays
    /// unique and tied to its original exercise even when equipment is occupied.
    var guidedExercise: HCExercise? {
        if let activeID = liftClock?.setExerciseID {
            return workout.exercises.first(where: { $0.id == activeID })
        }
        if let choice = validChoice(selectedGuidedSet) {
            return workout.exercises.first(where: { $0.id == choice.exerciseID })
        }
        if let selected = workout.exercises.first(where: { $0.id == guidedExerciseID }),
           firstUnfinishedSet(in: selected) != nil {
            return selected
        }
        guard let next = recommendedChoice() else { return nil }
        return workout.exercises.first(where: { $0.id == next.exerciseID })
    }

    var guidedSetNumber: Int {
        if liftClock?.setStartedAt != nil, let number = liftClock?.setNumber {
            return number
        }
        if let choice = validChoice(selectedGuidedSet) { return choice.setNumber }
        if let movement = guidedExercise,
           let number = firstUnfinishedSet(in: movement) { return number }
        return 1
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

    func selectGuidedSet(_ exercise: HCExercise, setNumber: Int) {
        let candidate = HCGuidedSetChoice(exerciseID: exercise.id, setNumber: setNumber)
        guard validChoice(candidate) != nil else { return }
        if liftClock?.setStartedAt != nil {
            // Don't discard a set already being performed: queue the choice for
            // immediately after Next saves the active set.
            queuedNextGuidedSet = candidate
            save(candidate, name: "queued-guided-set.json")
            status = "Set \(setNumber) of \(exercise.name) selected next"
        } else {
            selectedGuidedSet = candidate
            guidedExerciseID = exercise.id
            save(candidate, name: "guided-set-selection.json")
            save(exercise.id, name: "guided-exercise-id.json")
            status = "Set \(setNumber) of \(exercise.name) is next"
        }
    }

    /// A busy machine may require changing the active set before it is done.
    /// This intentionally abandons only its unrecorded timer, never a logged set.
    func switchToQueuedSetNow() {
        guard let choice = validChoice(queuedNextGuidedSet),
              let exercise = workout.exercises.first(where: {
                  $0.id == choice.exerciseID
              }) else { return }
        if liftClock?.setStartedAt != nil { cancelSet() }
        queuedNextGuidedSet = nil
        try? FileManager.default.removeItem(at:
            directory.appendingPathComponent("queued-guided-set.json"))
        selectGuidedSet(exercise, setNumber: choice.setNumber)
        if let rest = liftClock?.restEndsAt, rest > Date() {
            skipRest()
        } else {
            startSet(for: exercise)
        }
        status = "Switched to \(exercise.name) set \(choice.setNumber) without logging the previous set"
    }

    func selectGuidedExercise(_ exercise: HCExercise) {
        guard let number = firstUnfinishedSet(in: exercise) else { return }
        selectGuidedSet(exercise, setNumber: number)
    }

    func moveToNextGuidedExercise() {
        guard liftClock?.setStartedAt == nil else { return }
        if let next = recommendedChoice(after: guidedExerciseID) {
            selectGuidedSet(
                workout.exercises.first(where: { $0.id == next.exerciseID })!,
                setNumber: next.setNumber)
        }
    }

    private func publishLiftSessionStatus(startedAt: Date?, active: Bool) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        // The current lift session status is replaceable state. Activation,
        // reachability and foreground callbacks must not enqueue identical
        // user-info transfers, each of which can time out independently.
        let signature = workout.id + "|" + workout.date + "|" +
            (startedAt.map { String($0.timeIntervalSince1970) } ?? "none") +
            "|" + (active ? "active" : "inactive")
        guard signature != lastLiftStateSignature else { return }
        let state = HCWatchLiftSessionStatus(
            workoutID: workout.id,
            workoutDate: workout.date,
            startedAt: startedAt,
            isActive: active,
            reportedAt: Date()
        )
        guard let data = try? encoder.encode(state) else { return }
        let packet: [String: Any] = [
            HCPayload.kind: HCPayload.liftSessionStatus,
            HCPayload.data: data
        ]
        // Only the latest status is relevant. Cancel older pending STATUS
        // packets (never logged sets, runs, workout undo or their receipts).
        for transfer in session.outstandingUserInfoTransfers
            where transfer.userInfo[HCPayload.kind] as? String ==
                HCPayload.liftSessionStatus {
            transfer.cancel()
        }
        lastLiftStateSignature = signature
        session.transferUserInfo(packet)
        if session.isReachable {
            session.sendMessage(packet, replyHandler: { _ in },
                                errorHandler: { _ in })
        }
    }

    // MARK: - Full strength session clock

    func startLifting() {
        invalidatePreviousDayIfNeeded()
        guard hasScheduledLift, workout.date == Self.today(), !workout.exercises.isEmpty,
              !guidedAllFinished,
              liftClock?.isActive != true && runClock?.isActive != true else { return }
        liftClock = HCTrainingClock(workoutID: workout.id, startedAt: Date())
        let first = workout.exercises.first(where: {
            completedSets(for: $0).count < $0.prescribedSets
        })
        guidedExerciseID = first?.id
        selectedGuidedSet = nil
        queuedNextGuidedSet = nil
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("guided-set-selection.json"))
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("queued-guided-set.json"))
        if let first {
            save(first.id, name: "guided-exercise-id.json")
        }
        save(liftClock, name: "lifting-clock.json")
        publishLiftSessionStatus(startedAt: liftClock?.startedAt, active: true)
        // Pressing START WORKOUT starts the first working set immediately.
        if let first { startSet(for: first) }
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
        let pausedTime = Date().timeIntervalSince(paused)
        clock.pausedSeconds += pausedTime
        // Pausing the workout also pauses its prescribed recovery countdown.
        if let rest = clock.restEndsAt {
            clock.restEndsAt = rest.addingTimeInterval(pausedTime)
        }
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
        selectedGuidedSet = nil
        queuedNextGuidedSet = nil
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("guided-set-selection.json"))
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("queued-guided-set.json"))
        save(clock, name: "lifting-clock.json")
        publishLiftSessionStatus(startedAt: clock.startedAt, active: false)
        if let latestSchedule { applySchedule(latestSchedule) }
        invalidatePreviousDayIfNeeded()
    }

    // MARK: - Per-set clock and rest period

    func startSet(for exercise: HCExercise) {
        guard var clock = liftClock, clock.isActive, !clock.isPaused,
              clock.setStartedAt == nil, clock.workoutID == workout.id,
              !guidedAllFinished else { return }
        if let until = clock.restEndsAt, until > Date() { return }
        let choice: HCGuidedSetChoice
        if let chosen = validChoice(selectedGuidedSet), chosen.exerciseID == exercise.id {
            choice = chosen
        } else if let number = firstUnfinishedSet(in: exercise) {
            choice = HCGuidedSetChoice(exerciseID: exercise.id, setNumber: number)
        } else { return }
        clock.setExerciseID = exercise.id
        clock.setNumber = choice.setNumber
        guidedExerciseID = exercise.id
        save(exercise.id, name: "guided-exercise-id.json")
        clock.setStartedAt = Date()
        clock.restEndsAt = nil
        liftClock = clock
        save(clock, name: "lifting-clock.json")
    }

    /// Rest uses wall-clock time so the next set can start after wrist-down
    /// or an app re-launch. A timer drives this while the screen is visible.
    func advanceAfterRestIfReady() {
        // Existing default remains automatic so installed Watch behavior
        // does not change. An athlete may choose manual start in Preferences.
        guard UserDefaults.standard.object(forKey: "hcAutoStartNextSet") as? Bool ?? true
        else { return }
        guard let clock = liftClock, clock.isActive, !clock.isPaused,
              clock.setStartedAt == nil, !guidedAllFinished,
              (clock.restEndsAt == nil || clock.restEndsAt! <= Date()) else { return }
        guard let next = guidedExercise else { return }
        startSet(for: next)
    }

    func cancelSet() {
        guard var clock = liftClock, clock.setStartedAt != nil else { return }
        clock.setStartedAt = nil
        clock.setExerciseID = nil
        clock.setNumber = nil
        liftClock = clock
        save(clock, name: "lifting-clock.json")
    }

    @discardableResult
    func stopSet(for exercise: HCExercise, weightLb: Double?, reps: Int,
                 rir: Double?) -> Bool {
        guard var clock = liftClock, clock.isActive, !clock.isPaused,
              clock.setExerciseID == exercise.id,
              let started = clock.setStartedAt,
              reps > 0, reps <= 300,
              weightLb == nil || (weightLb! >= 0 && weightLb! <= 3000),
              rir == nil || ((rir! >= 0) && (rir! <= 10)) else { return false }
        let setNumber = clock.setNumber ?? guidedSetNumber
        guard setNumber > 0, setNumber <= exercise.prescribedSets,
              !completedSets(for: exercise, setNumber: setNumber) else { return false }

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
            index: setNumber,
            weightLb: weightLb,
            reps: reps,
            rir: rir,
            completedAt: now
        )
        entry.startedAt = started
        entry.durationSeconds = now.timeIntervalSince(started)
        sets.append(entry)
        save(sets, name: "sets.json")
        uploadPendingCloudSets()

        clock.setExerciseID = nil
        clock.setStartedAt = nil
        clock.setNumber = nil

        let queued = validChoice(queuedNextGuidedSet)
        let next = queued ?? recommendedChoice(after: exercise.id)
        queuedNextGuidedSet = nil
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("queued-guided-set.json"))
        if let next {
            selectedGuidedSet = next
            guidedExerciseID = next.exerciseID
            save(next, name: "guided-set-selection.json")
            save(next.exerciseID, name: "guided-exercise-id.json")
        } else {
            selectedGuidedSet = nil
            try? FileManager.default.removeItem(at:
                directory.appendingPathComponent("guided-set-selection.json"))
        }

        let override = UserDefaults.standard.integer(forKey: "hcRestOverrideSeconds")
        let seconds = override > 0 ? override : exercise.restSeconds
        clock.restEndsAt = next != nil && seconds > 0 ?
            now.addingTimeInterval(Double(seconds)) : nil
        liftClock = clock
        save(clock, name: "lifting-clock.json")
        sendPending()
        // No second tap is needed when no rest was prescribed.
        if seconds <= 0 { advanceAfterRestIfReady() }
        return true
    }

    func skipRest() {
        guard var clock = liftClock else { return }
        clock.restEndsAt = nil
        liftClock = clock
        save(clock, name: "lifting-clock.json")
        advanceAfterRestIfReady()
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
            planID: clock.workoutID == "unscheduled-run" ? nil : clock.workoutID,
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
        if var plan = runPlan, plan.id == clock.workoutID && plan.date == finished.date {
            plan = HCRunPlan(id: plan.id, date: plan.date, title: plan.title,
                             notes: plan.notes, targetDistanceMiles: plan.targetDistanceMiles,
                             isCompleted: true, structuredSteps: plan.structuredSteps)
            runPlan = plan
            save(plan, name: "run-plan.json")
        }
        sendPending()
    }

    // MARK: - WatchConnectivity

    /// Watch-side counterpart diagnostic. This must not be confused with
    /// "the iPhone happens to be nearby": the system has to recognize the
    /// companion application and activate the WatchConnectivity session.
    func checkPhoneConnection() {
        guard WCSession.isSupported() else {
            phoneConnectionStatus = "WatchConnectivity unsupported"
            return
        }
        let connection = WCSession.default
        guard connection.activationState == .activated else {
            phoneConnectionStatus = "Watch session not activated"
            connection.activate()
            return
        }
        phoneConnectionStatus =
            "Direct iPhone link: " +
            (connection.isReachable ? "Available" : "Unavailable") +
            " · Companion: " +
            (connection.isCompanionAppInstalled ? "Recognized" : "Not registered") +
            " · Cloud: " + (cloudSignedIn ? "Signed in" : "Signed out") +
            (cloudSignedIn ? " (workouts sync independently)" : "")
    }

    /// A real round-trip probe avoids interpreting a boolean as a successful
    /// connection. No private workout information is sent by this diagnostic.
    func testPhoneLink() {
        checkPhoneConnection()
        guard WCSession.isSupported() else {
            phonePingStatus = "WatchConnectivity unavailable"
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated else {
            phonePingStatus = "Watch session not activated"
            session.activate()
            return
        }
        guard session.isReachable else {
            phonePingStatus = "No live route to iPhone for diagnostic ping"
            return
        }
        phonePingStatus = "Testing iPhone connection…"
        session.sendMessage([HCPayload.kind: "imunDiagnosticPingV1"], replyHandler: {
            [weak self] response in
            DispatchQueue.main.async {
                self?.phonePingStatus =
                    response["imunDiagnosticPong"] as? Bool == true
                    ? "iPhone replied · live connection works"
                    : "iPhone replied without diagnostic acknowledgment"
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.phonePingStatus = "Ping failed: " + error.localizedDescription
            }
        })
    }

    private func invalidatePreviousDayIfNeeded() {
        let today = Self.today()
        guard latestSchedule?.date != today else { return }
        scheduleState = "loading"
        scheduleUpdatedAt = nil
        latestSchedule = nil
        hasReceivedPhoneScheduleToday = false
        latestAppliedPhoneScheduleAt = nil
        latestFullCloudScheduleAt = nil
        runPlan = nil
        hasScheduledLift = false
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("run-plan.json"))
        // Preserve an in-progress workout until the user finishes it.
        if liftClock?.isActive != true {
            workout = .unscheduled(date: today)
            guidedExerciseID = nil
        }
    }

    private func applySchedule(_ schedule: HCWatchSchedule,
                               fromPhone: Bool = false,
                               fromFullCloud: Bool = false) {
        guard schedule.date == Self.today() else {
            invalidatePreviousDayIfNeeded()
            return
        }
        if fromPhone, let latestAppliedPhoneScheduleAt,
           latestAppliedPhoneScheduleAt > schedule.generatedAt {
            return
        }
        if fromPhone, let latestFullCloudScheduleAt,
           latestFullCloudScheduleAt > schedule.generatedAt {
            return
        }
        if fromFullCloud, let latestFullCloudScheduleAt,
           latestFullCloudScheduleAt > schedule.generatedAt {
            return
        }
        if let previous = latestSchedule, previous.date == schedule.date {
            // A cloud-strength fallback can have a newer timestamp than the
            // actual iPhone running plan. The iPhone is authoritative for runs.
            if !fromPhone && hasReceivedPhoneScheduleToday &&
               (!fromFullCloud ||
                schedule.generatedAt <=
                    (latestAppliedPhoneScheduleAt ?? .distantPast)) {
                return
            }
            if previous.state == "ready" && schedule.state == "loading" {
                return
            }
            if previous.generatedAt > schedule.generatedAt &&
               !fromPhone && !fromFullCloud { return }
        }
        if fromPhone && schedule.state == "ready" {
            latestAppliedPhoneScheduleAt = schedule.generatedAt
        }
        if fromFullCloud && schedule.state == "ready" {
            latestFullCloudScheduleAt = schedule.generatedAt
        }
        latestSchedule = schedule
        isRequestingSchedule = false
        scheduleState = schedule.state
        scheduleUpdatedAt = schedule.generatedAt
        if schedule.state == "ready" {
            runPlan = schedule.runPlan?.date == schedule.date ? schedule.runPlan : nil
            if let runPlan { save(runPlan, name: "run-plan.json") }
            else { try? FileManager.default.removeItem(at: directory.appendingPathComponent("run-plan.json")) }
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
            try? FileManager.default.removeItem(at: directory.appendingPathComponent("run-plan.json"))
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
        // A normal Refresh should work even when watchOS says the iPhone
        // companion is absent. The authenticated cloud route has its own
        // network transport and never waits for WatchConnectivity.
        if manual && cloudSignedIn {
            refreshCloudWorkout()
            uploadPendingCloudSets()
        }
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

    /// EITAN is independent of the workout schedule. The timestamp protects
    /// newer privacy preferences and scores against late queued packets.
    @discardableResult
    private func applyEitanPacket(_ packet: [String: Any]) -> Bool {
        guard let stamp = packet[HCPayload.eitanStamp] as? Double,
              stamp.isFinite, stamp > 0,
              let bytes = packet[HCPayload.eitanSnapshot] as? Data else {
            eitanSyncStatus = "No valid EITAN packet from iPhone"
            eitanTransportDetails = "Missing EITAN timestamp or snapshot bytes. Reinstall matching iPhone and Watch builds."
            return false
        }
        let protocolVersion = packet["hcEitanProtocolVersion"] as? Int ?? 2
        let phoneBuild = packet["hcEitanPhoneBuild"] as? String ?? "older iPhone build"
        eitanPhoneBuild = phoneBuild
        eitanTransportDetails = "Protocol \(protocolVersion) · iPhone build \(phoneBuild) · payload \(bytes.count) bytes"
        let previous = UserDefaults.standard.double(forKey: "hcEitanReceivedTimestamp")
        if stamp < previous {
            eitanSyncStatus = "Received older EITAN revision · previous data preserved"
            eitanTransportDetails += " · older than Watch's last accepted timestamp"
            return false
        }
        // An unrelated iPhone schedule refresh might carry an empty
        // wellness payload while its Health importer is loading. Do not
        // erase an already authenticated same-day cloud EITAN merely
        // because the older live transport has no score. Explicit opt-out
        // flags still clear it immediately below.
        if bytes.isEmpty,
           packet["hcEitanEnabled"] as? Bool != false,
           packet["hcEitanUseHealth"] as? Bool != false,
           eitanCloudReceivedAt != nil,
           eitanSnapshot?.date == Self.today() {
            eitanSyncStatus = "Showing private-cloud EITAN while iPhone importer loads"
            eitanTransportDetails += " · empty phone update ignored; cloud retained"
            return true
        }
        let reading: HCEitanSnapshot?
        if bytes.isEmpty {
            reading = nil
        } else {
            do {
                let decoded = try decoder.decode(HCEitanSnapshot.self, from: bytes)
                guard decoded.date == Self.today() else {
                    eitanSyncStatus = "EITAN belongs to " + decoded.date + ", not today"
                    eitanTransportDetails += " · stale score date"
                    return false
                }
                reading = decoded
            } catch {
                eitanSyncStatus = "Could not decode EITAN from iPhone"
                eitanTransportDetails += " · " + error.localizedDescription
                return false
            }
        }
        for key in ["hcEitanEnabled", "hcEitanUseHealth",
                    "hcEitanCoachingEnabled"] {
            if let enabled = packet[key] as? Bool {
                UserDefaults.standard.set(enabled, forKey: key)
            }
        }
        if let preferred = packet["hcEitanPrimaryWearable"] as? String,
           HCEitanWearableSource.choices.contains(preferred) {
            UserDefaults.standard.set(preferred,
                                      forKey: "hcEitanPrimaryWearable")
        }
        UserDefaults.standard.set(stamp, forKey: "hcEitanReceivedTimestamp")
        eitanSnapshot = reading
        if let reading {
            save(reading, name: "eitan-snapshot.json")
        } else {
            try? FileManager.default.removeItem(
                at: directory.appendingPathComponent("eitan-snapshot.json"))
        }
        eitanLastReceivedAt = Date()
        if let reading {
            eitanTransportDetails += reading.value == nil ?
                " · received score with insufficient baseline" :
                " · wellness score \(reading.value!) received"
        } else {
            eitanTransportDetails += " · iPhone sent no wellness snapshot"
        }
        if (packet["hcEitanEnabled"] as? Bool ?? true) == false {
            eitanSyncStatus = "EITAN display is off in iPhone Settings"
        } else if (packet["hcEitanUseHealth"] as? Bool ?? true) == false {
            eitanSyncStatus = "EITAN training-only mode synced"
        } else if reading != nil {
            eitanSyncStatus = reading?.value == nil
                ? "EITAN synced · building personal baseline"
                : "EITAN score synced from iPhone"
        } else {
            eitanSyncStatus = "Connected · waiting for iPhone Health readings"
        }
        return true
    }

    private func acknowledgeEitanIfReachable(_ stamp: Double) {
        let connection = WCSession.default
        guard stamp > 0, connection.activationState == .activated,
              connection.isReachable else { return }
        connection.sendMessage([
            HCPayload.kind: HCPayload.eitanReceipt,
            HCPayload.eitanStamp: stamp
        ], replyHandler: { _ in }, errorHandler: { _ in
            // The Watch already has the latest snapshot; live acknowledgement
            // failure is not a failure to display the received wellness data.
        })
    }

    private func queueEitanRequest(_ session: WCSession) {
        // A wellness score is replaceable state, NOT a background event.
        // Do not create transferUserInfo jobs that may repeatedly time out.
        let stored = session.receivedApplicationContext
        if stored[HCPayload.eitanStamp] != nil,
           applyEitanPacket(stored) {
            eitanSyncStatus =
                "Showing last EITAN received · open iMun on both devices for a fresh sync"
        } else {
            eitanSyncStatus =
                "iPhone not reachable · open iMun on iPhone and Watch to sync EITAN"
        }
    }

    func requestEitanSync(manual: Bool = true) {
        if !manual && Date().timeIntervalSince(lastEitanLiveRequestAt) < 25 {
            return
        }
        lastEitanLiveRequestAt = Date()
        guard WCSession.isSupported() else {
            eitanSyncStatus = "EITAN sync unsupported on this Watch"
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated else {
            eitanSyncStatus = "Connecting EITAN to iPhone…"
            session.activate()
            return
        }
        guard session.isReachable else {
            queueEitanRequest(session)
            refreshCloudEitan(force: true)
            return
        }
        eitanSyncStatus = "Requesting latest EITAN from iPhone…"
        eitanTransportDetails = "Live request sent · awaiting iPhone response"
        session.sendMessage([HCPayload.kind: HCPayload.eitanRequest],
            replyHandler: { [weak self] response in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if self.applyEitanPacket(response) {
                        self.acknowledgeEitanIfReachable(
                            response[HCPayload.eitanStamp] as? Double ?? 0)
                    } // Invalid responses retain the detailed rejection reason.
                }
            }, errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.queueEitanRequest(session)
                    self.refreshCloudEitan(force: true)
                    self.eitanTransportDetails = "iPhone did not answer live request: " +
                        error.localizedDescription
                }
            })
    }

    private func applyContext(_ context: [String: Any]) {
        // A Watch can keep its own design, particularly when the cloud route
        // works but WatchConnectivity does not. Only accept explicit opt-in.
        if (context["imunDesignSyncV1"] as? Bool == true) &&
           (UserDefaults.standard.object(forKey:"hcDesignAcceptPhoneAppearance") as? Bool ?? true) {
            let strings = [
                "hcDesignPreset", "hcDesignMode", "hcDesignAccentHex",
                "hcDesignBackgroundHex", "hcDesignSurfaceHex",
                "hcDesignTextHex", "hcDesignShape", "hcDesignButtonShape",
                "hcDesignFont", "hcDesignDensity", "hcDesignMotif",
                "hcDesignNavigation", "hcDesignProgress"
            ]
            for key in strings {
                if let value = context[key] as? String, value.count <= 40 {
                    if key != "hcDesignPreset" ||
                       IMUNPreset(rawValue: value) != nil {
                        UserDefaults.standard.set(value, forKey: key)
                    }
                }
            }
            for key in ["hcDesignCustomPalette", "hcDesignCustomGeometry",
                        "hcDesignReduceMotion"] {
                if let value = context[key] as? Bool {
                    UserDefaults.standard.set(value, forKey: key)
                }
            }
        }
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
        if let data = context[HCPayload.workoutUndos] as? Data,
           let corrections = try? decoder.decode([HCWorkoutUndo].self, from: data) {
            DispatchQueue.main.async {
                self.cloudUndoRecords = HCWorkoutUndo.merged(
                    local: self.cloudUndoRecords, cloud: corrections)
            }
        }
        if let data = context[HCPayload.schedule] as? Data,
           let snapshot = try? decoder.decode(HCWatchSchedule.self, from: data) {
            if Thread.isMainThread {
                if snapshot.date == Self.today() && snapshot.state == "ready" {
                    hasReceivedPhoneScheduleToday = true
                }
                applySchedule(snapshot, fromPhone: true)
            } else {
                DispatchQueue.main.async {
                    if snapshot.date == Self.today() && snapshot.state == "ready" {
                        self.hasReceivedPhoneScheduleToday = true
                    }
                    self.applySchedule(snapshot, fromPhone: true)
                }
            }
        }
        // Newer EITAN packets win even if old workout contexts arrive late.
        if context[HCPayload.eitanStamp] != nil {
            if Thread.isMainThread {
                _ = applyEitanPacket(context)
            } else {
                DispatchQueue.main.async { _ = self.applyEitanPacket(context) }
            }
        }
        if let data = context["hcRecoverySnapshot"] as? Data {
            let reading = data.isEmpty ? nil :
                (try? decoder.decode(HCRecoveryDatum.self, from: data))
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

    /// The cloud commit already succeeded. This is just a wake-up hint; a
    /// missing live link never blocks the persisted workout/undo record.
    private func notifyPhoneCloudProgressChanged() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isReachable else { return }
        session.sendMessage([
            HCPayload.kind: HCPayload.progressCloudChanged,
            "date": Self.today()
        ], replyHandler: { _ in }, errorHandler: { _ in })
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
            } else if kind == HCPayload.workoutUndo,
                      let undo = try? decoder.decode(HCWorkoutUndo.self, from: bytes) {
                inFlight.insert(undo.id)
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
        for undo in undoRecords where !confirmedIDs.contains(undo.id) &&
            (!queuedIDs.contains(undo.id) ||
             (forceResend && !inFlight.contains(undo.id))) {
            guard let data = try? encoder.encode(undo) else { continue }
            let packet: [String: Any] = [
                HCPayload.kind: HCPayload.workoutUndo, HCPayload.data: data
            ]
            session.transferUserInfo(packet)
            if session.isReachable {
                session.sendMessage(packet, replyHandler: { [weak self] response in
                    guard response["saved"] as? Bool == true else { return }
                    DispatchQueue.main.async { self?.markConfirmed(undo.id) }
                }, errorHandler: { _ in })
            }
            queuedIDs.insert(undo.id)
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
                self.checkPhoneConnection()
                self.sendPending()
                let stored = session.receivedApplicationContext
                if stored[HCPayload.eitanStamp] != nil {
                    _ = self.applyEitanPacket(stored)
                }
                // Cancel only obsolete EITAN request/receipt transfers
                // from older builds. Old receipt queues are one source of
                // misleading WCSessionTransferTimedOut console messages.
                // Never cancel workouts, sets, schedule, or undo records.
                for transfer in session.outstandingUserInfoTransfers {
                    let kind = transfer.userInfo[HCPayload.kind] as? String
                    if kind == HCPayload.eitanRequest ||
                       kind == HCPayload.eitanReceipt {
                        transfer.cancel()
                    }
                }
                if self.hasScheduledLift && self.workout.date == Self.today() {
                    self.publishLiftSessionStatus(
                        startedAt: self.liftClock?.startedAt,
                        active: self.liftClock?.isActive == true)
                }
                let manual = self.pendingManualScheduleRequest
                self.pendingManualScheduleRequest = false
                self.requestCurrentSchedule(manual: manual)
                self.requestEitanSync(manual: false)
            }
        } else if let error {
            DispatchQueue.main.async { self.status = error.localizedDescription }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.checkPhoneConnection()
            guard session.activationState == .activated, session.isReachable else { return }
            // Reconnection does not justify re-queuing every workout record
            // repeatedly. Preserve pending events and rate-limit automatic
            // retries; the manual Sync action can still force delivery.
            if Date().timeIntervalSince(self.lastAutomaticResendAt) >= 120 {
                self.lastAutomaticResendAt = Date()
                self.sendPending(forceResend: true)
            }
            if self.hasScheduledLift && self.workout.date == Self.today() {
                self.publishLiftSessionStatus(
                    startedAt: self.liftClock?.startedAt,
                    active: self.liftClock?.isActive == true)
            }
            self.requestCurrentSchedule()
            self.requestEitanSync(manual: false)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        DispatchQueue.main.async {
            self.applyContext(context)
            if let stamp = context[HCPayload.eitanStamp] as? Double,
               self.applyEitanPacket(context) {
                // Acknowledge only AFTER the payload decoded and its date was
                // validated. An app context update isn't inherently a success.
                self.acknowledgeEitanIfReachable(stamp)
            }
        }
    }

    /// Only acknowledge a schedule after it decodes and has been applied.
    /// A transport-level reply by itself must not be reported as a loaded lift.
    private func confirmedSchedule(_ incoming: HCWatchSchedule) -> Bool {
        guard let current = latestSchedule,
              current.date == incoming.date,
              current.state == incoming.state,
              current.workout?.id == incoming.workout?.id,
              current.runPlan == incoming.runPlan,
              runPlan == incoming.runPlan else { return false }
        // An ongoing older workout is intentionally protected from replacement,
        // but in that case the new workout is not yet available for training.
        if incoming.state == "ready", let scheduled = incoming.workout {
            return workout.id == scheduled.id && hasScheduledLift
        }
        return true
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if message[HCPayload.kind] as? String == HCPayload.progressCloudChanged {
            DispatchQueue.main.async {
                if message["date"] as? String == Self.today() {
                    self.refreshCloudSets()
                }
                replyHandler(["received": true])
            }
            return
        }
        if message[HCPayload.kind] as? String == HCPayload.eitanSync {
            DispatchQueue.main.async {
                let accepted = self.applyEitanPacket(message)
                replyHandler(["eitanReceived": accepted,
                              HCPayload.eitanStamp:
                                message[HCPayload.eitanStamp] as? Double ?? 0])
            }
            return
        }
        guard message[HCPayload.kind] as? String == HCPayload.pushSchedule,
              let bytes = message[HCPayload.schedule] as? Data,
              let incoming = try? decoder.decode(HCWatchSchedule.self, from: bytes),
              incoming.date == Self.today() else {
            replyHandler(["received": false, "reason": "Missing or outdated workout schedule"])
            return
        }
        DispatchQueue.main.async {
            self.applyContext(message)
            let accepted = self.confirmedSchedule(incoming)
            replyHandler([
                "received": accepted,
                "scheduleState": self.scheduleState,
                "workoutID": self.latestSchedule?.workout?.id ?? "",
                "runID": self.runPlan?.id ?? "",
                "runSignature": self.runPlan?.syncSignature ?? "",
                "reason": accepted ? "" : "Watch did not load the same strength and running plans"
            ])
        }
    }

    func session(_ session: WCSession,
                 didFinish userInfoTransfer: WCSessionUserInfoTransfer,
                 error: Error?) {
        let kind = userInfoTransfer.userInfo[HCPayload.kind] as? String ?? "unknown"
        DispatchQueue.main.async {
            if let error {
                self.lastBackgroundTransfer =
                    "Background \(kind) failed: " + error.localizedDescription
            } else {
                self.lastBackgroundTransfer =
                    "Background \(kind) transfer completed (not app acknowledgment)"
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if userInfo[HCPayload.kind] as? String == HCPayload.eitanSync {
            DispatchQueue.main.async {
                guard self.applyEitanPacket(userInfo) else { return }
                // An older build might still have EITAN userInfo in flight.
                // Do not enqueue yet another background receipt that will
                // itself time out; use a small interactive acknowledgment.
                self.acknowledgeEitanIfReachable(
                    userInfo[HCPayload.eitanStamp] as? Double ?? 0)
            }
            return
        }
        if userInfo[HCPayload.kind] as? String == HCPayload.pushSchedule {
            guard let bytes = userInfo[HCPayload.schedule] as? Data,
                  let incoming = try? decoder.decode(HCWatchSchedule.self, from: bytes),
                  incoming.date == Self.today() else { return }
            DispatchQueue.main.async {
                self.applyContext(userInfo)
                guard self.confirmedSchedule(incoming) else { return }
                // A queued transfer also deserves a receipt: otherwise iPhone
                // cannot distinguish "sent" from "loaded" when Watch was offline.
                session.transferUserInfo([
                    HCPayload.kind: HCPayload.scheduleReceipt,
                    "date": incoming.date,
                    "scheduleState": incoming.state,
                    "workoutID": incoming.workout?.id ?? "",
                    "runID": self.runPlan?.id ?? "",
                    "runSignature": self.runPlan?.syncSignature ?? ""
                ])
            }
            return
        }
        if userInfo[HCPayload.kind] as? String == HCPayload.workoutUndo,
           let bytes = userInfo[HCPayload.data] as? Data,
           let item = try? decoder.decode(HCWorkoutUndo.self, from: bytes) {
            DispatchQueue.main.async {
                self.appendUndo(item, forwardToPhone: false)
            }
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

 
// The cloud fallback is deliberately isolated from WatchConnectivity. A failed
// Apple companion-app registration cannot prevent an authenticated Watch from
// fetching the owner's published workout and uploading unique logged sets.
private enum HCWatchCloudError: LocalizedError {
    case noSession
    case malformed
    case service(String)
    var errorDescription: String? {
        switch self {
        case .noSession: return "Sign in on Apple Watch."
        case .malformed: return "Unexpected cloud response."
        case .service(let message): return message
        }
    }
}

private struct HCWatchCloudToken: Codable {
    let userID: String
    let access: String
    let refresh: String
    let expiresAt: Date
}

private actor HCWatchCloudFallback {
    private let base = URL(string: "https://ecmosmmqloyahsdcxvpz.supabase.co")!
    // Supabase publishable key; user data remains protected by JWT and RLS.
    private let publishableKey = "sb_publishable_ClssY_cSAW7Lv7O2VG6jBg_yTDZW1fJ"
    private var token: HCWatchCloudToken? = HCWatchCloudFallback.loadToken()

    private static let service = "imun.watch.cloud"
    private static let account = "session"

    private static func query() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private static func loadToken() -> HCWatchCloudToken? {
        var query = Self.query()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(HCWatchCloudToken.self, from: data)
    }

    private static func saveToken(_ token: HCWatchCloudToken) {
        guard let data = try? JSONEncoder().encode(token) else { return }
        SecItemDelete(Self.query() as CFDictionary)
        var attributes = Self.query()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func hasSession() -> Bool { token != nil }

    private func parseToken(_ data: Data) throws -> HCWatchCloudToken {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any],
              let userID = user["id"] as? String else {
            throw HCWatchCloudError.malformed
        }
        let seconds = (json["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        return HCWatchCloudToken(userID: userID, access: access, refresh: refresh,
                                 expiresAt: Date().addingTimeInterval(seconds))
    }

    func signIn(email: String, password: String) async throws {
        let data = try await request(path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "password")],
            method: "POST", json: ["email":email,"password":password], bearer: nil)
        let received = try parseToken(data)
        token = received
        Self.saveToken(received)
    }

    private func authorized() async throws -> HCWatchCloudToken {
        guard let current = token else { throw HCWatchCloudError.noSession }
        if current.expiresAt > Date().addingTimeInterval(60) { return current }
        let data = try await request(path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            method: "POST", json: ["refresh_token": current.refresh], bearer: nil)
        let updated = try parseToken(data)
        token = updated
        Self.saveToken(updated)
        return updated
    }

    private func request(path: String, query: [URLQueryItem] = [],
                         method: String = "GET", json: Any? = nil,
                         bearer: String?, prefer: String? = nil) async throws -> Data {
        guard var parts = URLComponents(url: base.appendingPathComponent(
            String(path.dropFirst())), resolvingAgainstBaseURL: false) else {
            throw HCWatchCloudError.malformed
        }
        if !query.isEmpty { parts.queryItems = query }
        guard let url = parts.url else { throw HCWatchCloudError.malformed }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 25
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearer {
            request.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization")
        }
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let json {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HCWatchCloudError.malformed
        }
        guard (200...299).contains(http.statusCode) else {
            let errorData = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw HCWatchCloudError.service(
                (errorData?["msg"] as? String)
                ?? (errorData?["error_description"] as? String)
                ?? (errorData?["message"] as? String)
                ?? "Request failed (HTTP " + String(http.statusCode) + ")")
        }
        return data
    }

    func fetchWorkoutUndos(for workout: HCWorkout) async throws -> [HCWorkoutUndo] {
        let session = try await authorized()
        let response = try await request(
            path: "/rest/v1/health_coach_workout_undos",
            query: [
                URLQueryItem(name: "select", value:
                    "id,kind,set_id,workout_date,session_key,window_started_at,window_ended_at,created_at"),
                URLQueryItem(name: "user_id", value: "eq." + session.userID),
                URLQueryItem(name: "workout_date", value: "eq." + workout.date),
                URLQueryItem(name: "session_key", value: "eq." + workout.sessionKey),
                URLQueryItem(name: "limit", value: "500")
            ], bearer: session.access)
        guard let rows = try JSONSerialization.jsonObject(with: response) as? [[String: Any]]
        else { throw HCWatchCloudError.malformed }
        return HCWorkoutUndo.decodeCloudRows(rows)
    }

    func recordWorkoutUndo(_ undo: HCWorkoutUndo) async throws {
        let session = try await authorized()
        let response = try await request(
            path: "/rest/v1/rpc/imun_undo_workout_record",
            method: "POST", json: undo.apiPayload,
            bearer: session.access)
        guard let ok = (try? JSONSerialization.jsonObject(
            with: response, options: .fragmentsAllowed)) as? Bool,
              ok else { throw HCWatchCloudError.malformed }
    }

    func fetchCompletedSets(for workout: HCWorkout) async throws -> [HCLoggedSet] {
        let session = try await authorized()
        let data = try await request(path: "/rest/v1/health_coach_watch_sets",
            query: [
                URLQueryItem(name: "select", value:
                    "id,workout_date,session_key,workout_title,exercise_id,exercise_name,exercise_index,set_index,weight_lb,reps,rir,completed_at,started_at,duration_seconds,source"),
                URLQueryItem(name: "user_id", value: "eq." + session.userID),
                URLQueryItem(name: "workout_date", value: "eq." + workout.date),
                URLQueryItem(name: "session_key", value: "eq." + workout.sessionKey),
                URLQueryItem(name: "limit", value: "500")
            ], bearer: session.access)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { throw HCWatchCloudError.malformed }
        return HCSetReconciliation.decodeCloudRows(rows, workout: workout)
    }

    func fetchVisualPreferences() async throws -> [String: Any]? {
        let session = try await authorized()
        let data = try await request(
            path: "/rest/v1/health_coach_visual_preferences",
            query: [
                URLQueryItem(name: "select", value: "design"),
                URLQueryItem(name: "user_id", value: "eq." + session.userID),
                URLQueryItem(name: "limit", value: "1")
            ],
            bearer: session.access)
        guard let rows = try JSONSerialization.jsonObject(with: data)
                as? [[String: Any]] else { throw HCWatchCloudError.malformed }
        return rows.first?["design"] as? [String: Any]
    }

    /// Consent-gated, private EITAN state owned by this authenticated user.
    /// EITAN health metrics are never inferred from workout tables.
    func fetchEitanForWatch() async throws ->
        (enabled: Bool, snapshot: HCEitanSnapshot?, updatedAt: Date?)? {
        let session = try await authorized()
        let data = try await request(
            path: "/rest/v1/health_coach_eitan_snapshots",
            query: [
                URLQueryItem(name: "select", value:
                    "enabled,score_date,snapshot,updated_at"),
                URLQueryItem(name: "user_id", value:
                    "eq." + session.userID),
                URLQueryItem(name: "limit", value: "1")
            ], bearer: session.access)
        guard let rows = try JSONSerialization.jsonObject(with: data)
                as? [[String: Any]] else { throw HCWatchCloudError.malformed }
        guard let row = rows.first,
              let enabled = row["enabled"] as? Bool else { return nil }
        let modified = (row["updated_at"] as? String).flatMap {
            ISO8601DateFormatter().date(from: $0)
        }
        guard enabled else { return (false, nil, modified) }
        let decoded: HCEitanSnapshot?
        if let raw = row["snapshot"] as? [String: Any] {
            let bytes = try JSONSerialization.data(withJSONObject: raw)
            decoded = try JSONDecoder().decode(HCEitanSnapshot.self,
                                               from: bytes)
        } else {
            decoded = nil
        }
        return (true, decoded, modified)
    }

    /// The same versioned daily schedule that iMun shows on iPhone.
    /// This is independent of WatchConnectivity's foreground reachability.
    func fetchPublishedSchedule(date: String) async throws -> HCWatchSchedule? {
        let session = try await authorized()
        let data = try await request(
            path: "/rest/v1/health_coach_watch_schedules",
            query: [
                URLQueryItem(name: "select", value: "schedule"),
                URLQueryItem(name: "user_id", value: "eq." + session.userID),
                URLQueryItem(name: "workout_date", value: "eq." + date),
                URLQueryItem(name: "limit", value: "1")
            ], bearer: session.access)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { throw HCWatchCloudError.malformed }
        guard let raw = rows.first?["schedule"] as? [String: Any] else { return nil }
        let bytes = try JSONSerialization.data(withJSONObject: raw)
        let snapshot = try JSONDecoder().decode(HCWatchSchedule.self, from: bytes)
        guard snapshot.date == date, snapshot.state == "ready" else {
            throw HCWatchCloudError.malformed
        }
        return snapshot
    }

    func fetchPublishedWorkout(date: String) async throws -> HCWorkout? {
        let session = try await authorized()
        let data = try await request(path: "/rest/v1/health_coach_native_plans",
            query: [
                URLQueryItem(name: "select", value: "plan"),
                URLQueryItem(name: "user_id", value: "eq." + session.userID),
                URLQueryItem(name: "workout_date", value: "eq." + date),
                URLQueryItem(name: "limit", value: "1")
            ], bearer: session.access)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { throw HCWatchCloudError.malformed }
        guard let raw = rows.first?["plan"] as? [String: Any] else { return nil }
        return try JSONDecoder().decode(HCWorkout.self,
            from: JSONSerialization.data(withJSONObject: raw))
    }

    func upload(_ set: HCLoggedSet) async throws {
        let session = try await authorized()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var body: [String: Any] = [
            "id": set.id.uuidString.lowercased(),
            "user_id": session.userID,
            "workout_date": set.workoutDate,
            "session_key": set.sessionKey,
            "workout_title": set.workoutTitle,
            "exercise_id": set.exerciseID,
            "exercise_name": set.exerciseName,
            "exercise_index": set.exerciseIndex,
            "set_index": set.index,
            "reps": set.reps,
            "completed_at": iso.string(from: set.completedAt),
            "source": set.source ?? "Apple Watch"
        ]
        body["weight_lb"] = set.weightLb.map { $0 as Any } ?? NSNull()
        body["rir"] = set.rir.map { $0 as Any } ?? NSNull()
        body["started_at"] = set.startedAt.map { iso.string(from: $0) as Any } ?? NSNull()
        body["duration_seconds"] = set.durationSeconds.map { $0 as Any } ?? NSNull()
        _ = try await request(path: "/rest/v1/health_coach_watch_sets",
            query: [URLQueryItem(name: "on_conflict", value: "id")],
            method: "POST", json: [body], bearer: session.access,
            prefer: "resolution=ignore-duplicates,return=minimal")
    }
}
