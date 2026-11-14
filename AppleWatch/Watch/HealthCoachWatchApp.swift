import SwiftUI

@main
struct HealthCoachWatchApp: App {
    @StateObject private var store = WatchWorkoutStore()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView()
                .environmentObject(store)
        }
    }
}
