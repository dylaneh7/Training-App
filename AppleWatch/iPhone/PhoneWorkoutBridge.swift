import Foundation
import Combine
import WatchConnectivity

/// Owns the iPhone/watch connection, offline queue and Health Coach cloud sync.
/// Watch-origin events are persisted *before* attempting a network request.
final class PhoneWorkoutBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var workout: HCWorkout?
    @Published private(set) var loggedSets: [HCLoggedSet] = []
    @Published private(set) var status = "Preparing Health Coach…"
    @Published private(set) var signedIn = false
    @Published private(set) var loading = false
    @Published private(set) var cloudPendingCount = 0

    private let cloud = HCCloudClient()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var uploadedIDs: Set<UUID> = []

    private var storageDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var setsURL: URL { storageDirectory.appendingPathComponent("health-coach-watch-sets.json") }
    private var uploadedURL: URL { storageDirectory.appendingPathComponent("uploaded-watch-set-ids.json") }

    override init() {
        super.init()
        if let data = try? Data(contentsOf: setsURL),
           let prior = try? decoder.decode([HCLoggedSet].self, from: data) {
            loggedSets = prior
        }
        if let data = try? Data(contentsOf: uploadedURL),
           let ids = try? decoder.decode([UUID].self, from: data) {
            uploadedIDs = Set(ids)
        }
        updatePendingCount()

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        } else {
            status = "Watch Connectivity is not available on this device."
        }
        Task {
            let existing = await cloud.signedInUserID
            DispatchQueue.main.async {
                self.signedIn = existing != nil
                if existing != nil { self.refresh(date: Date()) }
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
                    self.status = "Signed in to Health Coach."
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
        workout = nil
        status = "Signed out. Local logged sets are preserved on this phone."
    }

    func refresh(date: Date) {
        guard signedIn else { status = "Sign in to load your live plan."; return }
        loading = true
        status = "Loading your Health Coach plan…"
        Task {
            do {
                let snapshot = try await cloud.fetchPlannerAndHistory()
                // Prefer the exact exercises and rep/weight edits exported by
                // Health Coach web; use the locally versioned plan as fallback.
                let published = try? await cloud.fetchPublishedPlan(date: HCPlanBuilder.dateString(date))
                let planned = published ?? HCPlanBuilder.workout(for: date, planner: snapshot.planner,
                                                                history: snapshot.history)
                DispatchQueue.main.async {
                    self.workout = planned
                    self.loading = false
                    self.status = planned == nil
                        ? "No scheduled strength workout for this day."
                        : "Ready: \(planned!.title)"
                    if planned != nil { self.sendToWatch() }
                    self.retryPendingCloudSets()
                }
            } catch {
                DispatchQueue.main.async {
                    self.loading = false
                    self.status = "Cannot load plan: \(error.localizedDescription)"
                    self.retryPendingCloudSets()
                }
            }
        }
    }

    func sendToWatch() {
        guard let workout else { status = "No workout to send."; return }
        guard WCSession.isSupported() else { status = "Watch Connectivity unavailable."; return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled
        else {
            status = "Install Health Coach Watch on your paired Apple Watch first."
            return
        }
        do {
            let payload = try encoder.encode(workout)
            // Current workout replaces old context; logged sets use the reliable queue.
            try session.updateApplicationContext([HCPayload.workout: payload])
            status = "Workout sent or queued for Apple Watch."
        } catch {
            status = "Could not send workout: \(error.localizedDescription)"
        }
    }

    private func persistLocalSets() {
        guard let data = try? encoder.encode(loggedSets) else { return }
        do {
            try data.write(to: setsURL, options: .atomic)
        } catch {
            status = "Could not save watch set locally: \(error.localizedDescription)"
        }
    }

    private func updatePendingCount() {
        cloudPendingCount = loggedSets.filter { !uploadedIDs.contains($0.id) }.count
    }

    private func persistUploadedIDs() {
        if let bytes = try? encoder.encode(Array(uploadedIDs)) {
            try? bytes.write(to: uploadedURL, options: .atomic)
        }
        updatePendingCount()
    }

    func retryPendingCloudSets() {
        guard signedIn else { return }
        let pending = loggedSets.filter { !uploadedIDs.contains($0.id) }
        guard !pending.isEmpty else { updatePendingCount(); return }

        // A single sequential worker avoids simultaneous refresh-token requests.
        Task {
            for item in pending {
                do {
                    try await cloud.upload(item)
                    DispatchQueue.main.async {
                        self.uploadedIDs.insert(item.id)
                        self.persistUploadedIDs()
                        self.status = "Watch sets synced to Health Coach."
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.status = "Sets saved locally. Cloud will retry: \(error.localizedDescription)"
                    }
                    break
                }
            }
        }
    }

    private func accept(_ incoming: HCLoggedSet) {
        guard !loggedSets.contains(where: { $0.id == incoming.id }) else { return }
        loggedSets.append(incoming)
        persistLocalSets()
        updatePendingCount()
        status = "Received a set from Apple Watch."
        retryPendingCloudSets()
    }

    // MARK: - Watch Connectivity

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            if state == .activated {
                if self.workout != nil { self.sendToWatch() }
            } else if let error {
                self.status = error.localizedDescription
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo[HCPayload.kind] as? String == HCPayload.loggedSet,
              let payload = userInfo[HCPayload.data] as? Data,
              let set = try? decoder.decode(HCLoggedSet.self, from: payload)
        else { return }
        DispatchQueue.main.async { self.accept(set) }
    }
}
