import SwiftUI
import WatchKit
import AVFoundation
import Combine

private enum WTheme {
    static var bg: Color { IMUNStyle.palette.canvas }
    static var panel: Color { IMUNStyle.palette.surface }
    static var muted: Color { IMUNStyle.palette.secondary }
    static var lime: Color { IMUNStyle.palette.accent }
    static var onAccent: Color { IMUNStyle.onAccent }
    static var aqua: Color { IMUNStyle.palette.supporting }
    static var amber: Color { Color(red: 1, green: 0.7, blue: 0.35) }

    static func metric(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold,
                design: IMUNStyle.headingDesign).monospacedDigit()
    }
    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .heavy, design: IMUNStyle.headingDesign)
    }
}

private func wClock(_ time: TimeInterval) -> String {
    let seconds = max(0, Int(time))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

private struct WPrimary: View {
    let title: String
    let symbol: String
    var color: Color = WTheme.lime
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(color == WTheme.lime ? WTheme.onAccent : WTheme.bg)
                .frame(maxWidth: .infinity, minHeight: 65)
                .padding(.horizontal, 4)
                .background(color, in: IMUNPanelShape(
                    shape: IMUNStyle.buttonShape, corner: 15))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct WSecondary: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 49)
                .background(WTheme.panel, in: IMUNPanelShape(
                    shape: IMUNStyle.cardShape, corner: 13))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct WMetric: View {
    let title: String
    let value: String
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(WTheme.label(9))
                .foregroundStyle(WTheme.muted)
            Text(value)
                .font(WTheme.metric(24))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WStepper: View {
    let title: String
    let value: String
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Button(action: minus) {
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 48)
                    .background(WTheme.panel, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Decrease " + title)
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                Text(title.uppercased())
                    .font(WTheme.label(9))
                    .foregroundStyle(WTheme.muted)
                Text(value).font(WTheme.metric(23))
            }
            Spacer(minLength: 0)
            Button(action: plus) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 48)
                    .background(WTheme.panel, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Increase " + title)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

/// Always-visible, one-tap weight/reps adjustment. Large hit targets and a
/// centered readout make the active set editable without watchOS scrolling.
private struct WQuickEditor: View {
    let title: String
    let value: String
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: decrease) {
                Image(systemName: "minus")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 46, height: 46)
                    .foregroundStyle(.white)
                    .background(WTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decrease " + title)

            VStack(spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WTheme.muted)
                Text(value)
                    .font(WTheme.metric(27))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, minHeight: 44)

            Button(action: increase) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 46, height: 46)
                    .foregroundStyle(WTheme.onAccent)
                    .background(WTheme.lime, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Increase " + title)
        }
        .frame(minHeight: 48)
        .padding(.horizontal, 2)
    }
}

private struct WProgressHalo: View {
    let completed: Int
    let planned: Int
    var body: some View {
        ZStack {
            Circle().stroke(WTheme.panel, lineWidth: 8)
            Circle()
                .trim(from: 0, to: planned > 0 ?
                      min(1, Double(completed) / Double(planned)) : 0)
                .stroke(WTheme.lime, style: StrokeStyle(
                    lineWidth: 8,
                    lineCap: IMUNStyle.progressStyle == "segmented" ? .butt : .round,
                    dash: IMUNStyle.progressStyle == "segmented" ? [9, 5] : []))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(planned > 0 ? "\(min(completed, planned))" : "—")
                    .font(WTheme.metric(22))
                    .foregroundStyle(.white)
                Text(planned > 0 ? "OF \(planned)" : "SETS")
                    .font(WTheme.label(8)).foregroundStyle(WTheme.muted)
            }
        }
        .frame(width: 78, height: 78)
        .accessibilityLabel("\(completed) of \(planned) planned strength sets completed")
    }
}

// MARK: - EITAN (Biblical Hebrew: enduring / steadfast; iMun training momentum)
//
// This is NOT a recovery, medical-readiness or physiological prediction.
// Only recorded activity is used. Missing measurements never become zeroes.
private struct IMUNEitanComponent: Identifiable {
    let id: String
    let title: String
    let score: Int
    let weight: Double
    let explanation: String
}

private struct IMUNEitanScore {
    let value: Int?
    let parts: [IMUNEitanComponent]
    let activeDays: Int

    func score(for id: String) -> String {
        parts.first(where: { $0.id == id }).map { String($0.score) } ?? "—"
    }

    var headline: String {
        guard let value else { return "Building your baseline" }
        if value >= 80 { return "Strong momentum this week" }
        if value >= 60 { return "You're building momentum" }
        if value >= 30 { return "Progress is taking shape" }
        return "Every step builds momentum"
    }

    static func calculate(_ store: WatchWorkoutStore, includeSleep: Bool = false) -> IMUNEitanScore {
        let today = WatchWorkoutStore.today()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let week = formatter.string(from: calendar.date(byAdding: .day, value: -6,
                                                        to: Date()) ?? Date())
        var active = Set(store.allRecordedSets.filter {
            $0.workoutDate >= week && $0.workoutDate <= today
        }.map(\.workoutDate))
        active.formUnion(store.runHistory.filter {
            $0.date >= week && $0.date <= today
        }.map(\.date))
        active.formUnion(store.completedRuns.filter {
            formatter.string(from: $0.startedAt) >= week &&
            formatter.string(from: $0.startedAt) <= today
        }.map { formatter.string(from: $0.startedAt) })

        var components: [IMUNEitanComponent] = []
        var actions: [Double] = []
        if store.hasScheduledLift && store.workout.date == today,
           store.workout.prescribedSetCount > 0 {
            actions.append(min(1, Double(store.guidedCompletedSets) /
                               Double(store.workout.prescribedSetCount)))
        }
        if let run = store.runPlan, run.date == today {
            let finished = run.isCompleted || store.completedRuns.contains {
                $0.planID == run.id && $0.date == today
            }
            actions.append(finished ? 1 : 0)
        }
        if !actions.isEmpty {
            let ratio = actions.reduce(0, +) / Double(actions.count)
            components.append(IMUNEitanComponent(
                id: "action", title: "ACTION",
                score: Int((ratio * 100).rounded()), weight: 0.45,
                explanation: "Today's prescribed strength sets and any scheduled run completion. Rest days are not counted as missed workouts."))
        }

        // Four active days is an adjustable future reference, not a clinical
        // threshold. Count distinct days of real strength/run records.
        let consistency = min(1, Double(active.count) / 4)
        components.append(IMUNEitanComponent(
            id: "rhythm", title: "RHYTHM",
            score: Int((consistency * 100).rounded()), weight: 0.35,
            explanation: "\(active.count) distinct logged training day(s) in the past seven days, against a four-day reference."))

        if includeSleep, let recovery = store.recoverySummary,
           recovery.date >= formatter.string(from: calendar.date(byAdding: .day,
                                           value: -2, to: Date()) ?? Date()),
           recovery.date <= today,
           let seconds = recovery.sleepSeconds, seconds >= 2 * 3600,
           seconds <= 15 * 3600 {
            // Sleep duration is a simple 7.5-hour reference, NOT a sleep
            // quality, medical risk, recovery or training-readiness score.
            let sleep = min(1, seconds / (7.5 * 3600))
            components.append(IMUNEitanComponent(
                id: "sleep", title: "SLEEP",
                score: Int((sleep * 100).rounded()), weight: 0.20,
                explanation: String(format: "%.1f h of recorded sleep from %@ on %@, compared with a 7.5 h display reference.",
                                    seconds / 3600, recovery.source, recovery.date)))
        }

        // With no logged training and no planned session, a positive-looking
        // number would misrepresent sleep alone as personal progress.
        let hasTrainingEvidence = !active.isEmpty || !actions.isEmpty
        let total: Int?
        if hasTrainingEvidence {
            let w = components.reduce(0.0) { $0 + $1.weight }
            let weighted = components.reduce(0.0) {
                $0 + Double($1.score) * $1.weight
            }
            total = w > 0 ? max(0, min(100, Int((weighted / w).rounded()))) : nil
        } else {
            total = nil
        }
        return IMUNEitanScore(value: total, parts: components,
                               activeDays: active.count)
    }
}

private struct IMUNEitanHomeTile: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @AppStorage("hcEitanUseHealth") private var useHealth = true

    private var wellness: HCEitanSnapshot? {
        guard useHealth, let snapshot = store.eitanSnapshot,
              snapshot.date == WatchWorkoutStore.today() else { return nil }
        return snapshot
    }

    var body: some View {
        let training = IMUNEitanScore.calculate(store)
        let displayed = useHealth ? wellness?.value : training.value
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("EITAN")
                        .font(.system(size: 16, weight: .bold,
                                      design: IMUNStyle.headingDesign))
                        .tracking(1.3)
                        .foregroundStyle(IMUNStyle.palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(useHealth ? "BODY WELLNESS" : "TRAINING MOMENTUM")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(0.35)
                        .foregroundStyle(WTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WTheme.aqua)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(displayed.map(String.init) ?? "—")
                    .font(.system(size: 39, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(IMUNStyle.palette.ink)
                    .lineLimit(1)
                Text("/ 100")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WTheme.muted)
                Spacer(minLength: 2)
                Text(Date().formatted(.dateTime.weekday(.abbreviated).day()))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WTheme.muted)
                    .lineLimit(1)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(WTheme.muted.opacity(0.2))
                    Capsule().fill(WTheme.lime)
                        .frame(width: geometry.size.width *
                               CGFloat(displayed ?? 0) / 100)
                }
            }
            .frame(height: 5)
            if useHealth {
                if let wellness {
                    HStack(spacing: 6) {
                        ForEach(Array(wellness.factors.sorted {
                            $0.weight > $1.weight
                        }.prefix(3))) { factor in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(factor.title.uppercased())
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundStyle(WTheme.muted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(String(factor.value))
                                    .font(.system(size: 13, weight: .semibold,
                                                  design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(IMUNStyle.palette.ink)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text("PRIMARY · " + (wellness.primaryWearable ?? "Automatic"))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(WTheme.muted)
                        .lineLimit(1)
                    Text(wellness.value == nil ?
                         "Personal baseline developing" :
                         wellness.status)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WTheme.aqua)
                        .lineLimit(2)
                } else {
                    Text("Your wellness score will appear when data is available.")
                        .font(.system(size: 10))
                        .foregroundStyle(WTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(spacing: 4) {
                    ForEach(["action", "rhythm"], id: \.self) { key in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(key == "action" ? "ACTION" : "RHYTHM")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(WTheme.muted)
                            Text(training.score(for: key))
                                .font(.system(size: 13, weight: .semibold,
                                              design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(IMUNStyle.palette.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text(training.headline)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WTheme.aqua)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Eitan " + (useHealth ? "body wellness: " : "training momentum: ") +
            (displayed.map { "\($0) out of 100" } ?? "not enough data"))
    }
}

private struct IMUNEitanExplanation: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @AppStorage("hcEitanUseHealth") private var useHealth = true

    var body: some View {
        let training = IMUNEitanScore.calculate(store)
        let wellness = store.eitanSnapshot?.date == WatchWorkoutStore.today()
            ? store.eitanSnapshot : nil
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("EITAN · אֵיתָן")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(IMUNStyle.palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Enduring · steadfast · strong")
                    .font(.system(size: 11))
                    .foregroundStyle(WTheme.muted)
                Text((useHealth ? wellness?.value : training.value)
                        .map { "\($0) / 100" } ?? "Building baseline")
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WTheme.lime)
                    .minimumScaleFactor(0.7)
                if useHealth {
                    if let wellness {
                        Text("PRIMARY WEARABLE · " + (wellness.primaryWearable ?? "Automatic"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(WTheme.aqua)
                        Text(wellness.coverage)
                            .font(.system(size: 10))
                            .foregroundStyle(WTheme.muted)
                        ForEach(wellness.factors) { factor in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(factor.title)
                                        .font(.system(size: 11, weight: .semibold))
                                    Spacer()
                                    Text("\(factor.value)")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                Text(factor.detail)
                                    .font(.system(size: 10))
                                    .foregroundStyle(WTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(WTheme.panel,
                                        in: RoundedRectangle(cornerRadius: 12))
                        }
                        if let strategy = wellness.coachingPlan {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ISAIah · " + strategy.title.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(WTheme.lime)
                                Text("\(strategy.recordedTrainingStreak) recorded training days in a row · \(strategy.recentHardDays) high-effort days this week")
                                    .font(.system(size: 10))
                                    .foregroundStyle(WTheme.muted)
                                Text(strategy.message)
                                    .font(.system(size: 10))
                                    .foregroundStyle(WTheme.aqua)
                                    .fixedSize(horizontal: false, vertical: true)
                                ForEach(strategy.cues.prefix(2), id: \.self) { cue in
                                    Text("• " + cue)
                                        .font(.system(size: 10))
                                        .foregroundStyle(IMUNStyle.palette.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Text("Evidence: " + strategy.confidence)
                                    .font(.system(size: 9))
                                    .foregroundStyle(WTheme.muted)
                            }
                        } else {
                            Text(wellness.coaching)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(WTheme.aqua)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text("Your wellness score will appear here when your latest measurements are available.")
                            .font(.system(size: 11))
                            .foregroundStyle(WTheme.muted)
                    }
                    Text("Personal trends are observational, not diagnostic. Missing measurements do not count as zero; incompatible HRV methods and duplicate devices are not averaged. Coaching advice never changes a workout automatically.")
                        .font(.system(size: 10))
                        .foregroundStyle(WTheme.muted)
                } else {
                    ForEach(training.parts.filter { $0.id != "sleep" }) { part in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(part.title)
                                    .font(.system(size: 11, weight: .semibold))
                                Spacer()
                                Text("\(part.score)")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            Text(part.explanation)
                                .font(.system(size: 10))
                                .foregroundStyle(WTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(WTheme.panel,
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                    Text("Training-only mode uses action and weekly rhythm, with no physiological Health measurements.")
                        .font(.system(size: 10))
                        .foregroundStyle(WTheme.muted)
                }
                Text("EITAN (אֵיתָן) is a genuine Biblical Hebrew word associated with firmness, endurance and strength. It is iMun's chosen score name, not a Hebrew word for medical readiness.")
                    .font(.system(size: 10))
                    .foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .background(WTheme.bg)
        .navigationTitle("EITAN")
    }
}

/// A List-based navigation hub fixes the page-gesture / scrolling conflict on
/// watchOS. Large Strength and Run targets are immediately reachable.
struct WatchWorkoutView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @AppStorage("hcEitanEnabled") private var eitanEnabled = true
    @AppStorage("hcAccentStyle") private var accent = "crimson"
    @AppStorage("hcDesignPreset") private var visualPreset = "techno"
    @AppStorage("hcDesignCustomGeometry") private var visualCustom = false
    @AppStorage("hcDesignShape") private var visualShape = "rounded"
    @AppStorage("hcDesignFont") private var visualFont = "standard"
    @AppStorage("hcDesignCustomPalette") private var visualPalette = false
    @AppStorage("hcDesignAccentHex") private var visualAccent = "D4324F"
    @AppStorage("hcDesignBackgroundHex") private var visualBackground = "070C16"
    @AppStorage("hcDesignSurfaceHex") private var visualSurface = "212831"
    @AppStorage("hcDesignTextHex") private var visualInk = "F6F3E9"
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastCloudScheduleCheck = Date.distantPast
    @State private var lastCloudProgressCheck = Date.distantPast
    @State private var lastCloudEitanCheck = Date.distantPast
    @State private var lastCloudRunCheck = Date.distantPast
    // Short foreground cloud reconciliation while training; never promise
    // instantaneous offline or background delivery on either platform.
    private let progressPulse = Timer.publish(
        every: 6, on: .main, in: .common).autoconnect()

    private var primaryActions: some View {
Section {
                    if eitanEnabled {
                    NavigationLink {
                        IMUNEitanExplanation()
                    } label: {
                        IMUNEitanHomeTile()
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 5, leading: 8,
                                              bottom: 7, trailing: 8))
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(LinearGradient(
                                colors: [WTheme.lime.opacity(0.13), WTheme.panel],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                    )

                    }

                    NavigationLink {
                        WatchStrengthScreen()
                    } label: {
                        WDestination(symbol: "dumbbell.fill", title: "STRENGTH",
                                     detail: "Workouts · Sets · Rest", tint: WTheme.lime)
                    }
                    .listRowBackground(WTheme.panel)

                    NavigationLink {
                        WatchRunScreen()
                    } label: {
                        WDestination(symbol: "figure.run", title: "RUN",
                                     detail: "Today's plan · History", tint: WTheme.aqua)
                    }
                    .listRowBackground(WTheme.panel)
                }
    }

    private var isaiahBrief: some View {
Section("IsAIah · TODAY") {
                    WatchIsaiahDailyBrief()
                        .listRowBackground(WTheme.panel)
                }
    }

    private var trainingPlan: some View {
Section("TRAINING PLAN") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.scheduleState == "ready" ?
                             (store.hasScheduledLift ? store.workout.title :
                              "No strength workout scheduled") :
                             (store.scheduleState == "signedOut" ?
                              "Sign in on iPhone" : "Syncing today's plan"))
                            .font(.system(size: 13, weight: .semibold))
                        Text(store.runPlan?.title ?? "No run scheduled")
                            .font(.system(size: 11))
                            .foregroundStyle(WTheme.muted)
                    }
                    .listRowBackground(WTheme.panel)
                }
    }

    @ViewBuilder private var healthSummary: some View {
if let recovery = store.recoverySummary {
                    Section("HEALTH · " + recovery.source.uppercased()) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            WatchSmallHealthMetric(title: "SLEEP",
                                value: recovery.sleepSeconds.map {
                                    String(format: "%.1fh", $0 / 3600)
                                } ?? "—")
                            WatchSmallHealthMetric(title: "HRV",
                                value: recovery.hrvMS.map {
                                    String(format: "%.0f", $0) + "ms"
                                } ?? "—")
                            WatchSmallHealthMetric(title: "LOW HR",
                                value: recovery.dailyLowHR.map {
                                    String(format: "%.0f", $0) + "bpm"
                                } ?? "—")
                        }
                        .listRowBackground(WTheme.panel)
                        Text("Recorded " + recovery.date +
                             " · Source values are not combined")
                            .font(.system(size: 10))
                            .foregroundStyle(WTheme.muted)
                            .listRowBackground(WTheme.panel)
                    }
                } else {
                    Section("HEALTH") {
                        Text("Recovery measurements will appear here when available.")
                            .font(.system(size: 11))
                            .foregroundStyle(WTheme.muted)
                            .listRowBackground(WTheme.panel)
                    }
                }
    }

    private var preferences: some View {
Section("PREFERENCES") {
                    NavigationLink {
                        WatchPreferences()
                    } label: {
                        Label("SETTINGS", systemImage: "gearshape")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
    }

    private var trainingHistory: some View {
Section("YOUR TRAINING") {
                    if let latest = store.runHistory.first {
                        NavigationLink {
                            WatchRunDetail(run: latest)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("LATEST RUN · " + latest.date)
                                    .font(WTheme.label(10)).foregroundStyle(WTheme.aqua)
                                Text(latest.distanceMeters.map {
                                    String(format: "%.2f MI", $0 / 1609.344)
                                } ?? latest.title)
                                    .font(WTheme.metric(23))
                                Text(latest.source).font(.system(size: 11))
                                    .foregroundStyle(WTheme.muted)
                            }
                        }
                    } else {
                        Text("Connect Apple Health on your iPhone to load recent runs.")
                            .font(.system(size: 12))
                            .foregroundStyle(WTheme.muted)
                    }
                }
    }

    var body: some View {
        NavigationStack {
            List {
                primaryActions
                isaiahBrief
                trainingPlan
                healthSummary
                preferences
                trainingHistory
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .background(WTheme.bg.ignoresSafeArea())
            .navigationTitle("imun")
        }
        .tint(WTheme.lime)
        .preferredColorScheme(.dark)
        .animation(IMUNStyle.animationsEnabled ? .easeInOut(duration: 0.18) : nil,
                   value: visualPreset)
        .animation(IMUNStyle.animationsEnabled ? .easeInOut(duration: 0.18) : nil,
                   value: visualShape)
        .onAppear {
            store.checkPhoneConnection()
            store.requestCurrentSchedule()
            if store.cloudSignedIn {
                store.refreshCloudWorkout()
                store.refreshCloudSets()
                store.refreshCloudRunHistory(force: true)
                store.refreshCloudAppearance(force: true)
                store.refreshCloudEitan(force: true)
            }
        }
        .onReceive(progressPulse) { _ in
            guard scenePhase == .active, store.cloudSignedIn else { return }
            let now = Date()
            let isTraining = store.liftClock?.isActive == true ||
                             store.runClock?.isActive == true
            // During an active session, reconcile new phone/Watch sets
            // and undo events in seconds. Idle screens use a lighter rate.
            if now.timeIntervalSince(lastCloudProgressCheck) >=
                (isTraining ? 6 : 18) {
                lastCloudProgressCheck = now
                store.refreshCloudSets()
                store.uploadPendingCloudSets()
            }
            if now.timeIntervalSince(lastCloudScheduleCheck) >=
                (isTraining ? 12 : 30) {
                lastCloudScheduleCheck = now
                store.refreshCloudWorkout()
            }
            if now.timeIntervalSince(lastCloudRunCheck) >=
                (isTraining ? 24 : 60) {
                lastCloudRunCheck = now
                store.refreshCloudRunHistory()
            }
            if now.timeIntervalSince(lastCloudEitanCheck) >= 30 {
                lastCloudEitanCheck = now
                store.refreshCloudEitan()
                store.refreshCloudAppearance()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.checkPhoneConnection()
                store.requestCurrentSchedule()
                if store.cloudSignedIn {
                    store.refreshCloudWorkout()
                    store.refreshCloudRunHistory(force: true)
                    store.refreshCloudEitan(force: true)
                }
            }
        }
    }
}

private struct WDestination: View {
    let symbol: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 38)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(WTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 64)
    }
}

/// Compact, source-attributed numbers, never a fabricated composite score.
private struct WatchSmallHealthMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(WTheme.muted)
            Text(value)
                .font(.system(size: 17, weight: .bold,
                              design: IMUNStyle.headingDesign))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(IMUNStyle.palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// IsAIah's on-device daily brief is derived only from today's actual synced
/// plan and source-labelled readings. It never pretends a new model reply ran.
private struct WatchIsaiahDailyBrief: View {
    @EnvironmentObject private var store: WatchWorkoutStore

    private var trainingFocus: String {
        guard store.scheduleState == "ready" else {
            return "Your training plan is syncing. Open iMun on iPhone if it stays unavailable."
        }
        if store.hasScheduledLift, let run = store.runPlan {
            return "Strength: " + store.workout.title + ". Run: " + run.title + "."
        }
        if store.hasScheduledLift {
            return "Strength today: " + store.workout.title + "."
        }
        if let run = store.runPlan {
            return "Running today: " + run.title + "."
        }
        return "No sessions scheduled today. Use this space to prepare for the next one."
    }

    private var recoveryContext: String {
        guard let r = store.recoverySummary else {
            return "No recovery data synced yet. Train by your planned effort and how you feel."
        }
        let sleep = r.sleepSeconds.map { String(format: "%.1f h", $0 / 3600) }
        let hrv = r.hrvMS.map { String(format: "%.0f ms", $0) }
        let summary = [sleep.map { "sleep " + $0 }, hrv.map { "HRV " + $0 }]
            .compactMap { $0 }
            .joined(separator: " · ")
        return r.source + " (" + r.date + "): " +
            (summary.isEmpty ? "No sleep or HRV reading." : summary + ".") 
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                IMUNIsaiahMark(size: 31)
                Text("TODAY'S BRIEF")
                    .font(WTheme.label(11))
                    .foregroundStyle(IMUNStyle.palette.ink)
                Spacer(minLength: 0)
            }
            Text(trainingFocus)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(IMUNStyle.palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(recoveryContext)
                .font(.system(size: 10))
                .foregroundStyle(WTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Guided Strength: one obvious action and automatic set progression

private func wHaptic(_ type: WKHapticType) {
    if UserDefaults.standard.object(forKey: "hcWatchHaptics") as? Bool ?? true {
        WKInterfaceDevice.current().play(type)
    }
}

private struct WatchStrengthScreen: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession
    @State private var confirmFinish = false

    var body: some View {
        Group {
            if store.liftClock?.isActive == true {
                WatchGuidedSession(onFinish: { confirmFinish = true })
            } else {
                WatchStrengthReady()
            }
        }
        .background(WTheme.bg.ignoresSafeArea())
        .navigationTitle("Strength")
        .confirmationDialog("Finish this strength workout?", isPresented: $confirmFinish) {
            Button("Finish & Save") {
                store.endLifting()
                if health.kind == .strength { health.finish() }
                wHaptic(.success)
            }
            Button("Continue workout", role: .cancel) {}
        } message: {
            Text("Your completed sets will be saved.")
        }
    }
}

private struct WatchStrengthReady: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !store.hasScheduledLift {
                    Text(store.scheduleState == "ready" ? "REST DAY" : "TODAY'S TRAINING")
                        .font(WTheme.label()).tracking(1.5)
                        .foregroundStyle(WTheme.aqua)
                    Text(store.scheduleState == "ready" ? "No strength workout scheduled" :
                         "Checking today's workout…")
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                    Text(store.scheduleState == "ready" ?
                         "Enjoy your recovery day, or plan your next session." :
                         "Your next session will appear here.")
                        .font(.system(size: 12)).foregroundStyle(WTheme.muted)
                    WSecondary(title: "REFRESH", symbol: "arrow.clockwise") {
                        store.requestCurrentSchedule(manual: true)
                    }
                } else {
                Text("TODAY'S LIFT")
                    .font(WTheme.label()).tracking(1.5)
                    .foregroundStyle(WTheme.aqua)
                Text(store.workout.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(store.workout.exercises.count) movements · \(store.guidedCompletedSets)/\(store.workout.prescribedSetCount) sets complete")
                    .font(.system(size: 12)).foregroundStyle(WTheme.muted)
                if let first = store.guidedExercise ?? store.workout.exercises.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FIRST UP").font(WTheme.label(10)).foregroundStyle(WTheme.aqua)
                        Text(first.name)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                        Text("\(first.prescribedSets) × \(first.repDescription) reps")
                            .font(.system(size: 12)).foregroundStyle(WTheme.muted)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                }
                if store.workout.exercises.isEmpty {
                    Text("No exercises scheduled.")
                        .font(.system(size: 12)).foregroundStyle(WTheme.muted)
                }
                if store.guidedAllFinished {
                    Text("ALL PRESCRIBED SETS COMPLETE")
                        .font(WTheme.label(11))
                        .foregroundStyle(WTheme.lime)
                } else {
                    WPrimary(title: "START WORKOUT", symbol: "play.fill") {
                        store.startLifting()
                        if store.liftClock?.isActive == true {
                            health.start(kind: .strength)
                            // The Watch store already confirmed the first set
                            // with a single start haptic.
                        }
                    }
                    .disabled(store.workout.exercises.isEmpty || store.runClock?.isActive == true)
                }
                Text(store.workout.isPreview
                     ? "Preview plan · Sync from the iPhone for your real workout."
                     : "Start once, then follow each set. You can change exercises anytime.")
                    .font(.system(size: 11))
                    .foregroundStyle(WTheme.muted)
                }
            }
            .padding(8)
        }
        .scrollIndicators(.hidden)
    }
}

private struct WatchGuidedSession: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession
    @AppStorage("hcWeightIncrement") private var increment = 5.0
    @AppStorage("hcAutoStartNextSet") private var autoStartNextSet = true
    @AppStorage("hcWatchMotionRepAssist") private var motionRepAssist = false
    @State private var weight = 0.0
    @State private var hasWeight = false
    @State private var reps = 8
    @State private var rir = 2
    @State private var showSetPicker = false
    @State private var confirmUndoWorkout = false
    let onFinish: () -> Void

    private var current: HCExercise? { store.guidedExercise }
    private var setCount: Int {
        guard let current else { return 0 }
        return store.completedSets(for: current).count
    }
    private var active: Bool {
        guard let current else { return false }
        return store.liftClock?.setExerciseID == current.id &&
               store.liftClock?.setStartedAt != nil
    }
    private var otherActive: Bool {
        store.liftClock?.setStartedAt != nil && !active
    }
    private var nextSetToken: String {
        (current?.id ?? "none") + ":" + String(store.guidedSetNumber) + ":" + String(setCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                if store.liftClock?.isPaused == true {
                    WPrimary(title: "RESUME WORKOUT", symbol: "play.fill") {
                        store.resumeLifting()
                        health.resume()
                        wHaptic(.start)
                    }
                }

                if store.guidedAllFinished {
                    finishedSection
                } else if let current {
                    // Put the two most important editable values at the top.
                    // Do not hide the weight controls for exercises lacking
                    // a suggested load: a first-time lift starts at BW/0 lb.
                    HStack(spacing: 4) {
                        Text(current.name)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.white)
                        Spacer(minLength: 2)
                        Text("\(store.guidedSetNumber)/\(current.prescribedSets)")
                            .font(WTheme.metric(16))
                            .foregroundStyle(WTheme.lime)
                    }
                    .padding(.bottom, 2)

                    if let until = store.liftClock?.restEndsAt, !active {
                        TimelineView(.periodic(from: .now, by: 1)) { tick in
                            let timeLeft = max(0, until.timeIntervalSince(tick.date))
                            if timeLeft > 0 {
                                restPanel(seconds: timeLeft)
                            } else {
                                quickSetControls(current)
                            }
                            // The shared workout store handles the one-time
                            // rest haptic, even on another Watch screen.
                        }
                    } else {
                        quickSetControls(current)
                    }

                    ProgressView(value: Double(store.guidedCompletedSets),
                                 total: Double(max(1, store.workout.prescribedSetCount)))
                        .tint(WTheme.lime)
                        .accessibilityLabel("Workout progress")
                    HStack(spacing: 5) {
                        Text("\(store.guidedCompletedSets) / \(store.workout.prescribedSetCount) COMPLETED")
                            .font(WTheme.label(9))
                            .foregroundStyle(WTheme.muted)
                        Spacer(minLength: 1)
                        if active {
                            TimelineView(.periodic(from: .now, by: 1)) { tick in
                                Text("SET " + wClock(tick.date.timeIntervalSince(
                                    store.liftClock?.setStartedAt ?? tick.date)))
                                    .font(WTheme.label(10))
                                    .foregroundStyle(WTheme.amber)
                            }
                        }
                    }
                    .padding(.top, 3)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSetPicker.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                            Text(showSetPicker ? "HIDE SETS" : "CHOOSE ANY SET")
                            Spacer()
                            Image(systemName: showSetPicker ? "chevron.up" : "chevron.down")
                        }
                        .font(WTheme.label(11))
                        .foregroundStyle(WTheme.aqua)
                        .padding(12)
                        .background(WTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    if let queued = store.queuedNextGuidedSet,
                       let next = store.workout.exercises.first(where: { $0.id == queued.exerciseID }) {
                        Text("UP NEXT: \(next.name) · SET \(queued.setNumber)")
                            .font(WTheme.label(10))
                            .foregroundStyle(WTheme.aqua)
                            .fixedSize(horizontal: false, vertical: true)
                        if active {
                            Button {
                                store.switchToQueuedSetNow()
                                wHaptic(.click)
                            } label: {
                                Label("SWITCH NOW · NO SET LOGGED",
                                      systemImage: "arrow.triangle.2.circlepath")
                                    .font(WTheme.label(10))
                                    .foregroundStyle(WTheme.amber)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(WTheme.panel,
                                                in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if showSetPicker {
                        VStack(alignment: .leading, spacing: 13) {
                            Text("Pick any unfinished set. During your current set, a choice is queued next.")
                                .font(.system(size: 10))
                                .foregroundStyle(WTheme.muted)
                            ForEach(store.workout.exercises) { movement in
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(movement.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(2)
                                        Spacer(minLength: 4)
                                        Text("\(store.completedSets(for: movement).count)/\(movement.prescribedSets)")
                                            .font(WTheme.label(10))
                                            .foregroundStyle(WTheme.muted)
                                    }
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 35),
                                                                 spacing: 5)], spacing: 5) {
                                        ForEach(Array(1...max(1, movement.prescribedSets)),
                                                id: \.self) { number in
                                            let done = store.completedSets(for: movement,
                                                                          setNumber: number)
                                            let chosen = (store.queuedNextGuidedSet?.exerciseID == movement.id &&
                                                          store.queuedNextGuidedSet?.setNumber == number) ||
                                                (!active && store.guidedExercise?.id == movement.id &&
                                                 store.guidedSetNumber == number)
                                            Button {
                                                store.selectGuidedSet(movement, setNumber: number)
                                                showSetPicker = false
                                                wHaptic(.click)
                                            } label: {
                                                Image(systemName: done ? "checkmark" :
                                                      chosen ? "arrow.forward" : "\(number).circle")
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundStyle(chosen && !done ?
                                                        WTheme.onAccent : done ? WTheme.muted : .white)
                                                    .frame(maxWidth: .infinity, minHeight: 37)
                                                    .background(chosen && !done ?
                                                        WTheme.lime : WTheme.panel,
                                                        in: RoundedRectangle(cornerRadius: 9))
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(done || movement.prescribedSets < 1)
                                            .accessibilityLabel("\(movement.name) set \(number)" +
                                                                (done ? ", completed" : ", choose next"))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .background(WTheme.bg.opacity(0.9),
                                    in: RoundedRectangle(cornerRadius: 12))
                    }

                    WQuickEditor(title: "RIR", value: "\(rir)",
                                 decrease: { rir = max(0, rir - 1) },
                                 increase: { rir = min(10, rir + 1) })
                    .padding(.top, 4)
                } else {
                    Text("No unfinished exercises are available.")
                        .foregroundStyle(WTheme.muted)
                }

                if store.liftClock?.isPaused != true && !active {
                    Button {
                        store.pauseLifting()
                        health.pause()
                    } label: {
                        Label("PAUSE WORKOUT", systemImage: "pause.fill")
                            .font(WTheme.label(11))
                            .foregroundStyle(WTheme.muted)
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.plain)
                }
                if let last = store.lastUndoableSet {
                    Button {
                        store.undoSet(last.id)
                        wHaptic(.click)
                    } label: {
                        Label("UNDO SET", systemImage: "arrow.uturn.backward")
                            .font(WTheme.label(11))
                            .foregroundStyle(WTheme.aqua)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    confirmUndoWorkout = true
                } label: {
                    Label("UNDO WORKOUT", systemImage: "arrow.uturn.backward")
                        .font(WTheme.label(11))
                        .foregroundStyle(WTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                if !active {
                    Button(action: onFinish) {
                        Label("FINISH WORKOUT", systemImage: "checkmark.seal.fill")
                            .font(WTheme.label(11))
                            .foregroundStyle(WTheme.muted)
                            .frame(maxWidth: .infinity, minHeight: 43)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .background(WTheme.bg.ignoresSafeArea())
        .task(id: nextSetToken) {
            loadNextTargets()
        }
        .onAppear {
            store.processRestDeadline()
        }
        .confirmationDialog("Undo Workout?", isPresented: $confirmUndoWorkout) {
            Button("Undo Workout", role: .destructive) {
                if health.kind == .strength { health.undo() }
                store.undoLifting()
                wHaptic(.click)
            }
            Button("Keep Workout", role: .cancel) {}
        } message: {
            Text("Reverse this active session's sets. The prescribed workout remains available.")
        }
    }

    @ViewBuilder
    private func quickSetControls(_ exercise: HCExercise) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            WQuickEditor(
                title: "WEIGHT · LB",
                value: hasWeight ? weight.formatted() : "BW",
                decrease: {
                    if hasWeight && weight > 0 {
                        weight = max(0, weight - increment)
                        if weight == 0 { hasWeight = false }
                    }
                    wHaptic(.click)
                },
                increase: {
                    hasWeight = true
                    weight = min(1500, weight + increment)
                    wHaptic(.click)
                }
            )
            WQuickEditor(
                title: "REPS",
                value: String(reps),
                decrease: {
                    reps = max(1, reps - 1)
                    wHaptic(.click)
                },
                increase: {
                    reps = min(100, reps + 1)
                    wHaptic(.click)
                }
            )
            if active && motionRepAssist {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 5) {
                        Image(systemName: "waveform.path")
                            .foregroundStyle(WTheme.aqua)
                        Text("WATCH MOTION ESTIMATE")
                            .font(WTheme.label(9))
                            .foregroundStyle(WTheme.muted)
                    }
                    HStack(alignment: .center, spacing: 9) {
                        Text("\(store.estimatedMotionReps)")
                            .font(WTheme.metric(28))
                            .foregroundStyle(WTheme.lime)
                            .contentTransition(.numericText())
                        Spacer(minLength: 4)
                        Button {
                            reps = min(100, max(1, store.estimatedMotionReps))
                            wHaptic(.click)
                        } label: {
                            Text("USE ESTIMATE")
                                .font(WTheme.label(10))
                                .foregroundStyle(WTheme.onAccent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .background(WTheme.lime,
                                            in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(store.estimatedMotionReps < 1)
                    }
                    if let tempo = store.motionAverageRepSeconds {
                        Text(String(format: "Around %.1f sec/rep", tempo))
                            .font(.system(size: 11))
                            .foregroundStyle(WTheme.muted)
                    }
                    Text("Experimental · Confirm reps before saving")
                        .font(.system(size: 10))
                        .foregroundStyle(WTheme.muted)
                }
                .padding(11)
                .background(WTheme.panel,
                            in: RoundedRectangle(cornerRadius: 13))
            }
            Button {
                if active {
                    let saved = store.stopSet(for: exercise,
                                              weightLb: hasWeight ? weight : nil,
                                              reps: reps, rir: Double(rir))
                    if saved {
                        wHaptic(.success)
                    }
                } else if !otherActive && store.liftClock?.isPaused != true {
                    store.startSet(for: exercise)
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: active ? "checkmark.circle.fill" : "play.fill")
                    Text(active ? "NEXT · SAVE SET" : "START SET \(store.guidedSetNumber)")
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(active ? WTheme.bg : WTheme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 53)
                .background(active ? WTheme.amber : WTheme.lime,
                            in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(otherActive || store.liftClock?.isPaused == true)
            .accessibilityLabel(active ? "End set and save weight and repetitions" : "Start set")
            .padding(.top, 2)
        }
    }

    private func restPanel(seconds: TimeInterval) -> some View {
        VStack(alignment: .center, spacing: 6) {
            IMUNThemeRestHeader()
            Text(autoStartNextSet ? "NEXT SET AUTO-STARTS" :
                                      "NEXT SET STARTS WHEN YOU TAP")
                .font(WTheme.label(9))
                .foregroundStyle(WTheme.muted)
            IMUNThemeTimerFace(seconds: seconds, countsDown: true, compact: true)
            Button {
                store.skipRest()
                wHaptic(.click)
            } label: {
                Label("SKIP REST", systemImage: "forward.end.fill")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(WTheme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(WTheme.lime,
                                in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var finishedSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundStyle(WTheme.lime)
            IMUNThemeCompletionCallout(compact: true)
            Text("\(store.guidedCompletedSets) working sets logged")
                .font(.system(size: 12))
                .foregroundStyle(WTheme.muted)
            WPrimary(title: "FINISH WORKOUT", symbol: "checkmark.seal.fill",
                     action: onFinish)
        }
    }

    private func loadNextTargets() {
        guard let next = current else { return }
        let previous = store.completedSets(for: next).last
        let suggested = previous?.weightLb ?? next.suggestedWeightLb
        if let suggested, suggested > 0 {
            weight = suggested
            hasWeight = true
        } else {
            weight = 0
            hasWeight = false
        }
        reps = previous?.reps ?? next.repMin
        rir = Int((previous?.rir ?? 2).rounded())
    }
}

private struct WatchSessionOptions: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession
    @Environment(\.dismiss) private var dismiss
    let onFinish: () -> Void

    var body: some View {
        List {
            Text("The session timer continues until you pause or finish.")
                .font(.system(size: 12)).foregroundStyle(WTheme.muted)
            if store.liftClock?.isPaused == true {
                WPrimary(title: "RESUME WORKOUT", symbol: "play.fill") {
                    store.resumeLifting()
                    health.resume()
                    dismiss()
                }
            } else {
                WSecondary(title: "PAUSE WORKOUT", symbol: "pause.fill") {
                    store.pauseLifting()
                    health.pause()
                    dismiss()
                }
                .disabled(store.liftClock?.setStartedAt != nil)
            }
            WPrimary(title: "FINISH WORKOUT", symbol: "checkmark.seal.fill",
                     color: WTheme.amber) {
                dismiss()
                onFinish()
            }
            .disabled(store.liftClock?.setStartedAt != nil)
        }
        .listStyle(.plain)
        .navigationTitle("Workout options")
    }
}

private struct WatchMovementPicker: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(store.workout.exercises) { ex in
                Button {
                    store.selectGuidedExercise(ex)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(ex.name)
                            .font(.system(size: 14, weight: .bold))
                        Text("\(store.completedSets(for: ex).count)/\(ex.prescribedSets) sets complete")
                            .font(.system(size: 11))
                            .foregroundStyle(WTheme.muted)
                    }
                    .frame(minHeight: 53, alignment: .leading)
                }
                .disabled(store.completedSets(for: ex).count >= ex.prescribedSets)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Exercises")
    }
}

private struct WatchPreferences: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @AppStorage("hcDesignPreset") private var preset = "techno"
    @AppStorage("hcDesignCustomGeometry") private var customGeometry = false
    @AppStorage("hcDesignShape") private var cardShape = "rounded"
    @AppStorage("hcDesignFont") private var font = "standard"
    @AppStorage("hcDesignDensity") private var density = "balanced"
    @AppStorage("hcDesignAcceptPhoneAppearance") private var acceptPhoneLook = true
    @AppStorage("hcMotivationSource") private var motivationSource = "off"
    @AppStorage("hcMotivationTranslation") private var translation = "ESV"
    @AppStorage("hcWeightIncrement") private var increment = 5.0
    @AppStorage("hcRestOverrideSeconds") private var restOverride = 0
    @AppStorage("hcAutoStartNextSet") private var autoStartNextSet = true
    @AppStorage("hcWatchHaptics") private var haptics = true
    @AppStorage("hcWatchSetStartHaptics") private var setStartHaptics = true
    @AppStorage("hcWatchRestCompleteHaptics") private var restCompleteHaptics = true
    @AppStorage("hcWatchMotionRepAssist") private var motionRepAssist = false

    var body: some View {
        List {
            Section("YOUR VISUAL IDENTITY") {
                HStack {
                    Image(systemName: IMUNStyle.preset.symbol)
                        .font(.system(size: 21))
                        .foregroundStyle(WTheme.lime)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(IMUNStyle.preset.title)
                            .font(WTheme.metric(17))
                        Text(IMUNStyle.preset.tagline)
                            .font(.system(size: 10))
                            .foregroundStyle(WTheme.muted)
                    }
                }
                Picker("Design preset", selection: $preset) {
                    ForEach(IMUNPreset.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                Toggle("Use iPhone design from cloud", isOn: $acceptPhoneLook)
                    .tint(WTheme.lime)
                    .onChange(of: acceptPhoneLook) { _, enabled in
                        if enabled { store.refreshCloudAppearance(force: true) }
                    }
                if acceptPhoneLook {
                    Button {
                        store.refreshCloudAppearance(force: true)
                    } label: {
                        Label("FETCH IPHONE DESIGN", systemImage: "icloud.and.arrow.down")
                    }
                    .disabled(!store.cloudSignedIn)
                    Text(store.designCloudStatus)
                        .font(.system(size: 10))
                        .foregroundStyle(WTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Watch colors and layout stay independent.")
                        .font(.system(size: 10))
                        .foregroundStyle(WTheme.muted)
                }
                Toggle("Custom layout", isOn: $customGeometry)
                    .tint(WTheme.lime)
                if customGeometry {
                    Picker("Card shape", selection: $cardShape) {
                        Text("Rounded").tag("rounded")
                        Text("Square").tag("square")
                        Text("Chamfered").tag("chamfered")
                        Text("Pill").tag("pill")
                        Text("Asymmetric").tag("asymmetric")
                    }
                    Picker("Headings", selection: $font) {
                        Text("Classic serif").tag("serif")
                        Text("Clean sans").tag("standard")
                        Text("Rounded").tag("rounded")
                        Text("Technical mono").tag("monospaced")
                    }
                    Picker("Spacing", selection: $density) {
                        Text("Compact").tag("compact")
                        Text("Balanced").tag("balanced")
                        Text("Airy").tag("airy")
                    }
                }
            }
            Section("MOTIVATION (OPTIONAL)") {
                Picker("Content", selection: $motivationSource) {
                    Text("Off").tag("off")
                    Text("Original").tag("original")
                    Text("Performance").tag("performance")
                    Text("Scripture").tag("scripture")
                    Text("My words").tag("custom")
                }
                if motivationSource == "scripture" {
                    Picker("Reference translation", selection: $translation) {
                        Text("ESV").tag("ESV")
                        Text("LSB").tag("LSB")
                    }
                }
                if let line = IMUNMotivation.line {
                    Text(line)
                        .font(.system(size: 12, weight: .medium,
                                      design: IMUNStyle.headingDesign))
                        .foregroundStyle(WTheme.muted)
                }
            }
            Section("TRAINING CONTROLS") {
                Picker("Weight steps", selection: $increment) {
                    Text("2.5 lb").tag(2.5)
                    Text("5 lb").tag(5.0)
                    Text("10 lb").tag(10.0)
                }
                Picker("Rest duration", selection: $restOverride) {
                    Text("Use program").tag(0)
                    Text("60 seconds").tag(60)
                    Text("90 seconds").tag(90)
                    Text("2 minutes").tag(120)
                    Text("3 minutes").tag(180)
                }
                Toggle("Start next set automatically after rest",
                       isOn: $autoStartNextSet)
                    .tint(WTheme.lime)
                Text(autoStartNextSet
                    ? "The Watch will start the next set when rest finishes. The first set starts with Start Workout."
                    : "Rest still counts down and alerts you. Tap Start Set when you are ready; no next set begins on its own.")
                    .font(.caption2).foregroundStyle(WTheme.muted)
                Toggle("Haptic feedback", isOn: $haptics)
                    .tint(WTheme.lime)
                    .onChange(of: haptics) { _, _ in
                        store.refreshRestAlertPreferences()
                    }
                if haptics {
                    Toggle("Tap when each set starts", isOn: $setStartHaptics)
                        .tint(WTheme.lime)
                    Toggle("Alert when rest finishes", isOn: $restCompleteHaptics)
                        .tint(WTheme.lime)
                        .onChange(of: restCompleteHaptics) { _, _ in
                            store.refreshRestAlertPreferences()
                        }
                    if restCompleteHaptics {
                        Button {
                            store.enableBackgroundRestAlerts()
                        } label: {
                            Label("ENABLE BACKGROUND REST ALERTS",
                                  systemImage: "bell.badge")
                        }
                        Text(store.restNotificationStatus)
                            .font(.caption2)
                            .foregroundStyle(WTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Watch notifications can alert you after rest even when you leave the workout screen. Delivery follows Watch notification and Focus settings.")
                            .font(.caption2)
                            .foregroundStyle(WTheme.muted)
                    }
                }
                Toggle("Experimental motion rep estimate",
                       isOn: $motionRepAssist)
                    .tint(WTheme.lime)
                    .onChange(of: motionRepAssist) { _, _ in
                        store.refreshMotionRepPreference()
                    }
                Text("Uses Watch wrist motion only while you perform a strength set. Counts are suggestions; you choose or edit reps before saving. Best for distinct, rhythmic arm movements; less reliable for many lifts.")
                    .font(.caption2)
                    .foregroundStyle(WTheme.muted)
                Text("Running voice cues and automatic miles remain in the Run screen.")
                    .font(.caption2).foregroundStyle(WTheme.muted)
            }
            WatchConnectivityDiagnostics()
        }
        .listStyle(.plain)
        .navigationTitle("Settings")
        .background(WTheme.bg.ignoresSafeArea())
    }
}

/// Connection tests are intentionally isolated in Settings rather than
/// presenting implementation detail under fitness and wellness cards.
/// Only Settings holds connectivity metadata; each component is deliberately
/// small enough for SwiftUI's watchOS compiler to type-check independently.
private struct WatchConnectivityDiagnostics: View {
    var body: some View {
        Section("CONNECTIVITY & DIAGNOSTICS") {
            WatchEitanSyncSettings()
            WatchTransportConnectionSettings()
        }
    }
}

private struct WatchEitanSyncSettings: View {
    var body: some View {
        NavigationLink {
            WatchEitanDetailsSettings()
        } label: {
            Label("EITAN & WATCH DETAILS", systemImage: "waveform.path.ecg")
        }
    }
}

/// watchOS does not support DisclosureGroup. Keep connection and recovery
/// tools behind a dedicated Settings destination rather than the dashboard.
private struct WatchEitanDetailsSettings: View {
    var body: some View {
        List {
            Section("EITAN STATUS") {
                WatchEitanTransportDetails()
            }
            Section("SYNC & RECOVERY") {
                WatchEitanRecoveryControls()
            }
        }
        .listStyle(.plain)
        .navigationTitle("EITAN Details")
        .background(WTheme.bg.ignoresSafeArea())
    }
}

private struct WatchEitanTransportDetails: View {
    @EnvironmentObject private var store: WatchWorkoutStore

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
                Text(store.eitanSyncStatus)
                    .font(.system(size: 10))
                    .foregroundStyle(WTheme.aqua)
                    .fixedSize(horizontal: false, vertical: true)
                Text(store.eitanTransportDetails)
                    .font(.system(size: 9))
                    .foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Workout transfer diagnostics · " + store.lastBackgroundTransfer)
                    .font(.system(size: 9))
                    .foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("WATCH BUILD " +
                     (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") +
                     " · PHONE " + store.eitanPhoneBuild)
                    .font(.system(size: 9))
                    .foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Installed Watch ID · " +
                     (Bundle.main.bundleIdentifier ?? "unknown"))
                    .font(.system(size: 9))
                    .foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Declared iPhone companion · " +
                     (Bundle.main.infoDictionary?[
                        "WKCompanionAppBundleIdentifier"] as? String ?? "missing"))
                    .font(.system(size: 9))
                    .foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let received = store.eitanLastReceivedAt {
                    Text("Last received " +
                         received.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(WTheme.muted)
                }
        }
    }
}

private struct WatchEitanRecoveryControls: View {
    @EnvironmentObject private var store: WatchWorkoutStore

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
                Button {
                    store.requestEitanSync()
                } label: {
                    Label("SYNC EITAN FROM IPHONE",
                          systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
                .tint(WTheme.lime)
                Divider()
                Text("PRIVATE CLOUD · NO IPHONE CONNECTION REQUIRED")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WTheme.lime)
                Text(store.eitanCloudStatus)
                    .font(.system(size: 10))
                    .foregroundStyle(WTheme.aqua)
                    .fixedSize(horizontal: false, vertical: true)
                if store.cloudSignedIn {
                    Button {
                        store.refreshCloudEitan(force: true)
                    } label: {
                        Label("LOAD EITAN FROM PRIVATE CLOUD",
                              systemImage: "icloud.and.arrow.down")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(WTheme.lime)
                } else {
                    NavigationLink {
                        WatchCloudBackupSetup()
                    } label: {
                        Label("SIGN IN TO IMUN CLOUD",
                              systemImage: "icloud")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                    .tint(WTheme.aqua)
                    Text("Use the same iMun account as the iPhone. On iPhone, enable Private EITAN cloud sync in Settings. No paired iPhone link is needed after sign-in.")
                        .font(.system(size: 10))
                        .foregroundStyle(WTheme.muted)
                }
                Text("Change EITAN and Health preferences in iPhone Settings.")
                    .font(.system(size: 10))
                    .foregroundStyle(WTheme.aqua)
        }
    }
}

private struct WatchTransportConnectionSettings: View {
    @EnvironmentObject private var store: WatchWorkoutStore

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
                Text("Watch build " +
                     (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))
                    .font(.system(size: 10))
                    .foregroundStyle(WTheme.muted)
                Button {
                    store.checkPhoneConnection()
                } label: {
                    Label("Check iPhone connection", systemImage: "iphone.gen3.radiowaves.left.and.right")
                }
                Button {
                    store.testPhoneLink()
                } label: {
                    Label("Test live iPhone link", systemImage: "waveform.path")
                }
                Text(store.phoneConnectionStatus)
                    .font(.system(size: 10)).foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(store.phonePingStatus)
                    .font(.system(size: 10)).foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    store.requestCurrentSchedule(manual: true)
                } label: {
                    Label("Refresh today's plan", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRequestingSchedule)
                Button {
                    store.refreshCloudWorkout()
                    store.refreshCloudSets()
                } label: {
                    Label("Test cloud connection", systemImage: "icloud.and.arrow.down")
                }
                .disabled(!store.cloudSignedIn)
                if !store.cloudSignedIn {
                    NavigationLink {
                        WatchCloudBackupSetup()
                    } label: {
                        Label("Cloud account", systemImage: "person.crop.circle")
                    }
                }
                Text(store.cloudStatus)
                    .font(.system(size: 10)).foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(store.progressSyncStatus)
                    .font(.system(size: 10)).foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let last = store.scheduleUpdatedAt {
                    Text("Last schedule sync: " +
                         last.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10)).foregroundStyle(WTheme.muted)
                }
                Text(store.status)
                    .font(.system(size: 10)).foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)        }
    }
}

// Watch is the recorder of record. All spoken cues come from Watch to avoid
// hearing duplicate prompts from the iPhone companion.
@MainActor
private final class IMUNRunCueCoach: ObservableObject {
    @Published private(set) var stage = "Free run"
    @Published private(set) var lastCue = "Cues follow the Watch workout session."

    private let speaker = AVSpeechSynthesizer()
    private var previousPhase = ""
    private var previousStart: Date?
    private var lastSpokenMinute = -1

    private func say(_ phrase: String, prominent: Bool = false) {
        lastCue = phrase
        if prominent { WKInterfaceDevice.current().play(.notification) }
        guard UserDefaults.standard.object(forKey: "hcRunVoiceCues") as? Bool == true else { return }
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.rate = 0.48
        utterance.volume = 0.95
        // Siri/headphone routing is owned by the operating system.
        speaker.speak(utterance)
    }

    private func pace(_ secondsPerMile: Double) -> String {
        guard secondsPerMile.isFinite, secondsPerMile > 0,
              secondsPerMile < 3_600 else { return "not available" }
        let rounded = Int(secondsPerMile.rounded())
        return "\(rounded / 60) minutes \(rounded % 60) seconds per mile"
    }

    private func phase(for elapsed: Double, plan: HCRunPlan?) -> (String, String) {
        // Prescribed intervals always override the old optional sample timer.
        // Do not turn an Easy 40-minute run into a made-up 5 x 3/2 session.
        if let plan {
            if let steps = plan.structuredSteps, !steps.isEmpty {
                var elapsedBeforeStep = 0.0
                for (index, step) in steps.enumerated() {
                    let heartRate: String = {
                        guard let low = step.minBPM, let high = step.maxBPM else { return "" }
                        return " · heart rate \(low) to \(high)"
                    }()
                    let label = step.title + heartRate
                    guard let seconds = step.seconds, seconds > 0 else {
                        // A distance/open step must never advance on a guessed timer.
                        return ("planned-\(index)", label)
                    }
                    if elapsed < elapsedBeforeStep + seconds {
                        return ("planned-\(index)", label)
                    }
                    elapsedBeforeStep += seconds
                }
                return ("planned-finished", "Planned intervals finished")
            }
            return ("planned", plan.title)
        }
        // A genuine unscheduled run may optionally use the legacy sample timer.
        guard UserDefaults.standard.bool(forKey: "hcRunIntervals") else {
            return ("free", "Free run")
        }
        if elapsed < 300 { return ("warm", "Warm up · 5 min") }
        let interval = elapsed - 300
        if interval < 5 * 300 {
            let cycle = Int(interval / 300) + 1
            if interval.truncatingRemainder(dividingBy: 300) < 180 {
                return ("work\(cycle)", "Effort \(cycle) of 5 · 3 min")
            }
            return ("recover\(cycle)", "Recovery \(cycle) of 5 · 2 min")
        }
        return ("cool", "Cool down")
    }

    func reset() {
        previousStart = nil
        previousPhase = ""
        lastSpokenMinute = -1
        stage = "Free run"
    }

    func tick(store: WatchWorkoutStore, health: WatchHealthSession) {
        guard let clock = store.runClock, clock.isActive else {
            if previousStart != nil { reset() }
            return
        }
        if previousStart != clock.startedAt {
            reset()
            previousStart = clock.startedAt
        }
        guard !clock.isPaused else { return }
        let elapsed = clock.duration()
        let next = phase(for: elapsed, plan: store.runPlan)
        stage = next.1
        if next.0 != previousPhase {
            previousPhase = next.0
            if next.0 != "free" {
                say(next.1 + " begins now.", prominent: true)
            } else if elapsed < 12 {
                say("Run started. Have a strong session.")
            }
        }

        let autoLap = UserDefaults.standard.object(forKey: "hcRunAutoLaps") as? Bool ?? true
        if autoLap, let lap = store.autoLapIfNeeded(currentDistanceMeters: health.distanceMeters) {
            let paceText: String = {
                guard let meters = lap.distanceMeters, meters > 0 else { return "pace unavailable" }
                return pace(lap.elapsedSeconds * 1609.344 / meters)
            }()
            let miles = Int((health.distanceMeters ?? 0) / 1609.344)
            say("Mile \(miles). Split pace \(paceText).", prominent: true)
        }

        let cadence = UserDefaults.standard.object(forKey: "hcRunCueMinutes") as? Int ?? 5
        let minute = Int(elapsed / 60)
        if cadence > 0 && minute > 0 && minute % cadence == 0 &&
           minute != lastSpokenMinute {
            lastSpokenMinute = minute
            var parts = ["\(minute) minutes completed"]
            if let distance = health.distanceMeters, distance > 100 {
                parts.append(String(format: "%.2f miles", distance / 1609.344))
                parts.append("Average pace " + pace(elapsed * 1609.344 / distance))
            }
            if let hr = health.heartRateBPM, hr > 0 {
                parts.append("Heart rate \(Int(hr))")
            }
            say(parts.joined(separator: ". ") + ".")
        }
    }
}

// MARK: - Running and imported run history

private struct WatchRunScreen: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession
    @StateObject private var cueCoach = IMUNRunCueCoach()
    @AppStorage("hcRunVoiceCues") private var voiceCues = false
    @AppStorage("hcRunAutoLaps") private var autoLaps = true
    @AppStorage("hcRunIntervals") private var intervals = false
    @AppStorage("hcRunCueMinutes") private var cueMinutes = 5
    private let cueTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    @State private var confirmFinish = false
    @State private var confirmUndoWorkout = false

    var body: some View {
        List {
            Section("TODAY'S PLAN") {
                VStack(alignment: .leading, spacing: 9) {
                    Text(store.runPlan?.title ?? "FREE RUN")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                    if let plan = store.runPlan {
                        if let target = plan.targetDistanceMiles {
                            Text(String(format: "TARGET  ·  %.2f MI", target))
                                .font(WTheme.label(11)).foregroundStyle(WTheme.aqua)
                        }
                        if plan.isCompleted {
                            Label("COMPLETED", systemImage: "checkmark.circle.fill")
                                .font(WTheme.label(12))
                                .foregroundStyle(WTheme.lime)
                        }
                        if let steps = plan.structuredSteps, !steps.isEmpty {
                            ForEach(Array(steps.enumerated()), id: \.offset) { indexed in
                                let step = indexed.element
                                let time: String = {
                                    if let seconds = step.seconds {
                                        return "\(Int(seconds / 60)) min"
                                    }
                                    if let distance = step.distanceMeters {
                                        return String(format: "%.2f mi", distance / 1609.344)
                                    }
                                    return "Open"
                                }()
                                let hr: String = {
                                    guard let low = step.minBPM, let high = step.maxBPM
                                    else { return "" }
                                    return " · \(low)–\(high) bpm"
                                }()
                                Text("\(step.title) · \(time)\(hr)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(WTheme.muted)
                            }
                        }
                        if !plan.notes.isEmpty {
                            Text(plan.notes)
                                .font(.system(size: 12))
                                .foregroundStyle(WTheme.muted)
                        }
                    } else {
                        Text(store.scheduleState == "ready" ?
                             "No run scheduled today. You can still start a free run." :
                             "Checking the latest run plan on iPhone.")
                            .font(.system(size: 12)).foregroundStyle(WTheme.muted)
                    }
                }
                .listRowBackground(WTheme.panel)
            }

            Section("LIVE PERFORMANCE") {
                TimelineView(.periodic(from: .now, by: 1)) { tick in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text((store.runClock?.isActive == true
                              ? cueCoach.stage : (store.runPlan?.title ?? "Free run")).uppercased())
                                .font(WTheme.label(11))
                                .foregroundStyle(WTheme.aqua)
                            Spacer()
                            if store.runClock?.isActive == true {
                                Circle().fill(WTheme.lime)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        let elapsed = store.runClock?.duration(at: tick.date) ?? 0
                        let distance = health.distanceMeters ?? 0
                        let averagePace = distance > 50 ?
                            wClock(elapsed * 1609.344 / distance) + "/mi" : "—"
                        Text(averagePace)
                            .font(WTheme.metric(29))
                            .foregroundStyle(WTheme.lime)
                        Text("AVERAGE PACE")
                            .font(WTheme.label(9))
                            .foregroundStyle(WTheme.muted)
                        if distance > 0 {
                            ProgressView(value: (distance / 1609.344).truncatingRemainder(dividingBy: 1))
                                .tint(WTheme.lime)
                            Text("Next mile · " + String(format: "%.2f / 1.00", (distance / 1609.344).truncatingRemainder(dividingBy: 1)))
                                .font(WTheme.label(10)).foregroundStyle(WTheme.muted)
                        }
                    }
                }
                .listRowBackground(WTheme.panel)
            }

            Section("AUDIO & INTERVAL COACH") {
                Toggle("Spoken headphone cues", isOn: $voiceCues)
                    .tint(WTheme.lime)
                Toggle("Automatic mile laps", isOn: $autoLaps)
                    .tint(WTheme.lime)
                Toggle("Timed intervals", isOn: $intervals)
                    .tint(WTheme.lime)
                if intervals {
                    Text("Preset: warm up 5 min · 5 × (3 min effort / 2 min easy) · cool down")
                        .font(.system(size: 11)).foregroundStyle(WTheme.muted)
                }
                Picker("Pace & HR cues", selection: $cueMinutes) {
                    Text("Off").tag(0)
                    Text("Every minute").tag(1)
                    Text("Every 2 min").tag(2)
                    Text("Every 5 min").tag(5)
                    Text("Every 10 min").tag(10)
                }
                Text(cueCoach.lastCue)
                    .font(.system(size: 11)).foregroundStyle(WTheme.muted)
            }

            Section("RUN CONTROLS") {
                TimelineView(.periodic(from: .now, by: 1)) { now in
                    VStack(alignment: .leading, spacing: 7) {
                        WMetric(title: "Elapsed time",
                                value: wClock(store.runClock?.duration(at: now.date) ?? 0),
                                tint: WTheme.aqua)
                        HStack {
                            WMetric(title: "Distance",
                                    value: health.distanceMeters.map {
                                        String(format: "%.2f mi", $0 / 1609.344)
                                    } ?? "—")
                            WMetric(title: "Heart rate",
                                    value: health.heartRateBPM.map {
                                        "\(Int($0)) bpm"
                                    } ?? "—")
                        }
                    }
                }
                .listRowBackground(WTheme.panel)

                if store.runClock?.isActive == true {
                    if store.runClock?.isPaused == true {
                        WPrimary(title: "RESUME RUN", symbol: "play.fill", color: WTheme.aqua) {
                            store.resumeRun()
                            health.resume()
                        }
                    } else {
                        WSecondary(title: "PAUSE RUN", symbol: "pause.fill") {
                            store.pauseRun()
                            health.pause()
                        }
                    }
                    WPrimary(title: "RECORD LAP", symbol: "flag.fill", color: WTheme.aqua) {
                        store.addRunSplit(currentDistanceMeters: health.distanceMeters)
                        wHaptic(.click)
                    }
                    WPrimary(title: "FINISH RUN", symbol: "checkmark.seal.fill",
                             color: WTheme.amber) { confirmFinish = true }
                    WSecondary(title: "UNDO WORKOUT",
                               symbol: "arrow.uturn.backward") {
                        confirmUndoWorkout = true
                    }
                } else if store.liftClock?.isActive == true {
                    Text("Finish your strength session before starting a run.")
                        .font(.system(size: 11)).foregroundStyle(WTheme.muted)
                } else {
                    WPrimary(title: "START RUN", symbol: "play.fill", color: WTheme.aqua) {
                        store.startRun()
                        health.start(kind: .run)
                        wHaptic(.start)
                    }
                }
            }

            Section("PREVIOUS RUNS") {
                ForEach(Array(store.runHistory.prefix(10))) { run in
                    NavigationLink {
                        WatchRunDetail(run: run)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(run.date).font(WTheme.label(10)).foregroundStyle(WTheme.aqua)
                            Text(run.distanceMeters.map {
                                String(format: "%.2f MI", $0 / 1609.344)
                            } ?? "Run recorded")
                                .font(WTheme.metric(19))
                            Text(run.source)
                                .font(.system(size: 11)).foregroundStyle(WTheme.muted)
                        }
                    }
                }
                if store.runHistory.isEmpty {
                    Text("No completed runs yet.")
                        .font(.system(size: 12)).foregroundStyle(WTheme.muted)
                }
            }
            if let splits = store.runClock?.splits, !splits.isEmpty {
                Section("RECORDED LAPS") {
                    ForEach(splits) { lap in
                        HStack {
                            Text("LAP \(lap.index)")
                            Spacer()
                            Text(wClock(lap.elapsedSeconds))
                                .font(WTheme.metric(16))
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .background(WTheme.bg.ignoresSafeArea())
        .navigationTitle("Run")
        .onReceive(cueTimer) { _ in
            cueCoach.tick(store: store, health: health)
        }
        .onAppear { cueCoach.tick(store: store, health: health) }
        .confirmationDialog("Undo Workout?", isPresented: $confirmUndoWorkout) {
            Button("Undo Workout", role: .destructive) {
                if health.kind == .run { health.undo() }
                store.undoRun()
                wHaptic(.click)
            }
            Button("Keep Workout", role: .cancel) {}
        } message: {
            Text("This reverses the active run without saving it to Apple Fitness.")
        }
        .confirmationDialog("Finish run?", isPresented: $confirmFinish) {
            Button("Finish & Save") {
                store.finishRun(distanceMeters: health.distanceMeters,
                                heartRateBPM: health.averageHeartRateBPM)
                if health.kind == .run { health.finish() }
                wHaptic(.success)
            }
        }
    }
}

private struct WatchRunDetail: View {
    let run: HCProgressRun

    var body: some View {
        List {
            Section {
                Text(run.date).font(WTheme.label(11)).foregroundStyle(WTheme.aqua)
                Text(run.source).font(.system(size: 12)).foregroundStyle(WTheme.muted)
                WMetric(title: "Distance", value: run.distanceMeters.map {
                    String(format: "%.2f mi", $0 / 1609.344)
                } ?? "Not shared", tint: WTheme.aqua)
                WMetric(title: "Elapsed", value: run.durationSeconds.map(wClock) ?? "—")
                if let meters = run.distanceMeters, meters > 0,
                   let elapsed = run.durationSeconds {
                    WMetric(title: "Average pace", value: wClock(elapsed * 1609.344 / meters) + "/mi")
                }
                if let pulse = run.averageBPM {
                    WMetric(title: "Average HR", value: "\(Int(pulse)) bpm")
                }
                if let max = run.maxBPM {
                    WMetric(title: "Max HR", value: "\(Int(max)) bpm")
                }
                if let calories = run.activeCalories {
                    WMetric(title: "Active energy", value: "\(Int(calories)) kcal")
                }
                if let power = run.averagePowerWatts {
                    WMetric(title: "Run power", value: "\(Int(power)) W")
                }
            }
            if !run.splits.isEmpty {
                Section("LAP EVENTS") {
                    ForEach(run.splits) { lap in
                        HStack {
                            Text("LAP \(lap.index)")
                            Spacer()
                            Text(wClock(lap.elapsedSeconds))
                                .font(WTheme.metric(16))
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .background(WTheme.bg.ignoresSafeArea())
        .navigationTitle("Run details")
    }
}

 
/// Optional alternate route when Apple's paired-app registration is unreliable.
/// Credentials are entered on the Watch and sent only to Supabase over HTTPS.
/// The refresh token is persisted only in this Watch's Keychain.
private struct WatchCloudBackupSetup: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                Text("DIRECT CLOUD SYNC")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WTheme.aqua)
                Text("Sign in to your existing iMun account once. The Watch can download workouts and, when enabled on the iPhone, your private EITAN wellness score—even when WatchConnectivity says Phone not connected.")
                    .font(.system(size: 11))
                    .foregroundStyle(WTheme.muted)
                TextField("Account email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
                    .textContentType(.password)
                Button("Sign in & load") {
                    store.signInToCloud(email: email, password: password)
                    password = ""
                }
                .disabled(email.isEmpty || password.isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(WTheme.lime)
                Text(store.cloudStatus)
                    .font(.system(size: 11))
                    .foregroundStyle(WTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 5)
        }
        .navigationTitle("Cloud backup")
    }
}
