import SwiftUI
import WidgetKit
import ActivityKit

private enum IWStyle {
    static let background = Color(red: 0.045, green: 0.051, blue: 0.075)
    static let surface = Color(red: 0.11, green: 0.12, blue: 0.15)
    static let crimson = Color(red: 0.77, green: 0.035, blue: 0.22)
    static let cream = Color(red: 0.97, green: 0.965, blue: 0.95)
    static let muted = Color(red: 0.65, green: 0.67, blue: 0.70)
}

private struct IMUNTodayEntry: TimelineEntry {
    let date: Date
    let workout: String
    let progress: String
    let running: String
    let sleep: String?
    let hrv: String?
    let source: String?
    let healthEnabled: Bool

    static var placeholder: IMUNTodayEntry {
        IMUNTodayEntry(date: Date(), workout: "Today's training",
                       progress: "—", running: "", sleep: nil,
                       hrv: nil, source: nil, healthEnabled: false)
    }

    static func load() -> IMUNTodayEntry {
        guard let defaults = UserDefaults(suiteName: IMUNWidgetKeys.suite) else {
            return .placeholder
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        // Never label yesterday's saved training snapshot as today's plan.
        guard defaults.string(forKey: IMUNWidgetKeys.date) ==
              formatter.string(from: Date()) else {
            return IMUNTodayEntry(date: Date(),
                                  workout: "Open iMun to refresh today's plan",
                                  progress: "—", running: "", sleep: nil, hrv: nil,
                                  source: nil, healthEnabled: false)
        }
        let sharedHealth = defaults.bool(forKey: IMUNWidgetKeys.healthEnabled)
        return IMUNTodayEntry(
            date: Date(),
            workout: defaults.string(forKey: IMUNWidgetKeys.workout) ?? "Open iMun for today's plan",
            progress: defaults.string(forKey: IMUNWidgetKeys.progress) ?? "—",
            running: defaults.string(forKey: IMUNWidgetKeys.running) ?? "",
            sleep: sharedHealth ? defaults.string(forKey: IMUNWidgetKeys.sleep) : nil,
            hrv: sharedHealth ? defaults.string(forKey: IMUNWidgetKeys.hrv) : nil,
            source: sharedHealth ? defaults.string(forKey: IMUNWidgetKeys.source) : nil,
            healthEnabled: sharedHealth
        )
    }
}

private struct IMUNTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> IMUNTodayEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (IMUNTodayEntry) -> Void) {
        completion(IMUNTodayEntry.load())
    }
    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<IMUNTodayEntry>) -> Void) {
        let entry = IMUNTodayEntry.load()
        completion(Timeline(entries: [entry],
                            policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

private struct IMUNTodayWidgetView: View {
    let entry: IMUNTodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(IWStyle.crimson)
                    .frame(width: 4, height: 16)
                Text("imun")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(IWStyle.cream)
                Spacer(minLength: 0)
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(IWStyle.muted)
            }
            Text(entry.workout)
                .font(.system(size: family == .systemSmall ? 16 : 18, weight: .semibold))
                .foregroundStyle(IWStyle.cream)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            if !entry.running.isEmpty {
                Text(entry.running)
                    .font(.system(size: 11))
                    .foregroundStyle(IWStyle.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SETS")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(IWStyle.muted)
                    Text(entry.progress)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(IWStyle.cream)
                }
                Spacer(minLength: 0)
                if family == .systemMedium && entry.healthEnabled {
                    if let sleep = entry.sleep {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("SLEEP")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(IWStyle.muted)
                            Text(sleep)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(IWStyle.cream)
                        }
                    }
                    if let hrv = entry.hrv {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("HRV")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(IWStyle.muted)
                            Text(hrv)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(IWStyle.cream)
                        }
                    }
                }
            }
            if family == .systemMedium && entry.healthEnabled, let source = entry.source {
                Text(source)
                    .font(.system(size: 9))
                    .foregroundStyle(IWStyle.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { IWStyle.background }
        .widgetURL(URL(string: "imun://today"))
    }
}

private struct IMUNAccessoryToday: View {
    let entry: IMUNTodayEntry
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "figure.run.circle")
            VStack(alignment: .leading) {
                Text("imun · TODAY")
                    .font(.system(size: 10, weight: .semibold))
                Text(entry.workout)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "imun://today"))
    }
}

private struct IMUNTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: IMUNWidgetKeys.kind, provider: IMUNTodayProvider()) {
            entry in
            IMUNTodayWidgetFamilyView(entry: entry)
        }
        .configurationDisplayName("iMun Today")
        .description("Your actual training plan and, optionally, source-labeled recovery.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct IMUNTodayWidgetFamilyView: View {
    let entry: IMUNTodayEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        if family == .accessoryRectangular {
            IMUNAccessoryToday(entry: entry)
        } else {
            IMUNTodayWidgetView(entry: entry)
        }
    }
}

/// Direct Lock Screen entry to the active training view.
private struct IMUNWorkoutShortcutView: View {
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Group {
            if family == .accessoryCircular {
                VStack(spacing: 2) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 19, weight: .semibold))
                    Text("IMUN")
                        .font(.system(size: 8, weight: .bold))
                }
            } else {
                HStack(spacing: 9) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 19))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iMun Training")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Tap to resume or start a workout")
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "imun://training"))
    }
}

private struct IMUNWorkoutShortcutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "imun.workout-shortcut",
                            provider: IMUNTodayProvider()) { _ in
            IMUNWorkoutShortcutView()
        }
        .configurationDisplayName("iMun Workout")
        .description("Open your current workout straight from the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct IMUNWorkoutActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IMUNWorkoutActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(IWStyle.crimson)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.workoutTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text("\(context.state.completedSets) / \(context.state.plannedSets) sets logged")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if let end = context.state.restEnd, end > Date() {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
            }
            .padding()
            .activityBackgroundTint(IWStyle.background)
            .activitySystemActionForegroundColor(IWStyle.cream)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.workoutTitle, systemImage: "dumbbell")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.completedSets)/\(context.state.plannedSets)")
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let end = context.state.restEnd, end > Date() {
                        Text(timerInterval: Date()...end, countsDown: true)
                            .font(.system(size: 12, weight: .medium))
                    } else {
                        Text("Workout in progress")
                            .font(.system(size: 12))
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
            } compactTrailing: {
                Text("\(context.state.completedSets)/\(context.state.plannedSets)")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "dumbbell.fill")
            }
            .widgetURL(URL(string: "imun://training"))
        }
    }
}

@main
struct IMUNWidgetBundle: WidgetBundle {
    var body: some Widget {
        IMUNTodayWidget()
        IMUNWorkoutShortcutWidget()
        IMUNWorkoutActivityWidget()
    }
}
