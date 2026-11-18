import SwiftUI

@main
struct HealthCoachPhoneApp: App {
    // A single Health reader lives at the app root. All tabs, navigation
    // destinations and modal presentations inherit the same observable object.
    @StateObject private var bridge = PhoneWorkoutBridge()
    @StateObject private var appleHealth = HCAppleHealthReader()

    var body: some Scene {
        WindowGroup {
            PremiumHomeView()
                .environmentObject(bridge)
                .environmentObject(appleHealth)
        }
    }
}
