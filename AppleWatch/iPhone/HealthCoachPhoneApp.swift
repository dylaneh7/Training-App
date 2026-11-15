import SwiftUI

@main
struct HealthCoachPhoneApp: App {
    @StateObject private var bridge = PhoneWorkoutBridge()

    var body: some Scene {
        WindowGroup {
            PremiumHomeView()
                .environmentObject(bridge)
        }
    }
}
