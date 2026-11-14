import Foundation
import WatchConnectivity

/// iPhone counterpart for the Apple Watch MVP.
/// This version stores received sets locally; it does NOT yet write to Supabase.
final class PhoneWorkoutBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var loggedSets: [HCLoggedSet] = []
    @Published private(set) var status = "Connecting to Apple Watch…"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var savedSetsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("watch-sets.json")
    }

    override init() {
        super.init()
        if let data = try? Data(contentsOf: savedSetsURL),
           let entries = try? decoder.decode([HCLoggedSet].self, from: data) {
            loggedSets = entries
        }

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        } else {
            status = "Watch Connectivity is unavailable on this device."
        }
    }

    func sendDemoWorkout() {
        guard WCSession.isSupported() else {
            status = "Watch Connectivity unavailable."
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else {
            status = "Pair your Apple Watch and install Health Coach Watch first."
            return
        }
        do {
            let data = try encoder.encode(HCWorkout.preview)
            try session.updateApplicationContext(["workout": data])
            status = "Full Upper workout queued for the watch."
        } catch {
            status = "Could not send workout: \(error.localizedDescription)"
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.status = state == .activated
                ? "Watch connection is ready."
                : (error?.localizedDescription ?? "Could not activate Watch Connectivity.")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo["kind"] as? String == "loggedSet",
              let payload = userInfo["payload"] as? Data,
              let logged = try? decoder.decode(HCLoggedSet.self, from: payload)
        else { return }

        DispatchQueue.main.async {
            // Idempotent by UUID; duplicate delivery cannot double-count a set.
            guard !self.loggedSets.contains(where: { $0.id == logged.id }) else { return }
            self.loggedSets.append(logged)
            if let data = try? self.encoder.encode(self.loggedSets) {
                try? data.write(to: self.savedSetsURL, options: .atomic)
            }
            self.status = "Received a logged set from Apple Watch."
        }
    }
}
