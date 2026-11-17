import Foundation

/// Shared between the iPhone and WidgetKit targets. Health values enter the
/// widget store ONLY if the athlete enables the opt-in setting.
enum IMUNWidgetKeys {
    static let suite = "group.com.dylaneh7.HealthCoachNative"
    static let kind = "imun.today"
    static let workout = "imun.widget.workout"
    static let progress = "imun.widget.progress"
    static let running = "imun.widget.running"
    static let sleep = "imun.widget.sleep"
    static let hrv = "imun.widget.hrv"
    static let source = "imun.widget.source"
    static let date = "imun.widget.date"
    static let healthEnabled = "imun.widget.healthEnabled"
}

#if os(iOS)
import ActivityKit

/// Live Activity state contains only the user's actual active workout.
struct IMUNWorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var completedSets: Int
        var plannedSets: Int
        var restEnd: Date?
        var syncPending: Int
    }

    var workoutTitle: String
    var startedAt: Date
}
#endif
