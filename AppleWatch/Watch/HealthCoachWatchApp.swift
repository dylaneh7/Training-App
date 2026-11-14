import SwiftUI

@main
struct HealthCoachWatchApp: App {
    @StateObject private var store = WatchWorkoutStore()
    @StateObject private var health = WatchHealthSession()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView()
                .environmentObject(store)
                .environmentObject(health)
        }
    }
}
