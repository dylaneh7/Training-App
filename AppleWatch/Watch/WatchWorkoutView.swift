import SwiftUI
import WatchKit
import AVFoundation
import Combine

private enum WTheme {
    static let bg = Color(red: 0.025, green: 0.047, blue: 0.065)
    static let panel = Color(red: 0.085, green: 0.115, blue: 0.145)
    static let muted = Color(red: 0.61, green: 0.70, blue: 0.73)
    static var lime: Color {
        switch UserDefaults.standard.string(forKey: "hcAccentStyle") ?? "crimson" {
        case "lime": return Color(red: 0.76, green: 0.98, blue: 0.43)
        case "aqua": return Color(red: 0.41, green: 0.85, blue: 0.82)
        case "white": return .white
        default: return Color(red: 0.83, green: 0.20, blue: 0.31)
        }
    }
    static var onAccent: Color {
        (UserDefaults.standard.string(forKey: "hcAccentStyle") ?? "crimson") == "crimson" ? .white : bg
    }
    static var aqua: Color {
        switch UserDefaults.standard.string(forKey: "hcAccentStyle") ?? "crimson" {
        case "crimson": return .white
        case "white": return Color(red: 0.83, green: 0.88, blue: 0.94)
        default: return Color(red: 0.41, green: 0.85, blue: 0.82)
        }
    }
    static let amber = Color(red: 1.0, green: 0.7, blue: 0.35)

    static func metric(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }
    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
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
                .background(color, in: RoundedRectangle(cornerRadius: 15))
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
                .background(WTheme.panel, in: RoundedRectangle(cornerRadius: 13))
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
                .stroke(WTheme.lime, style: StrokeStyle(lineWidth: 8, lineCap: .round))
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

/// A List-based navigation hub fixes the page-gesture / scrolling conflict on
/// watchOS. Large Strength and Run targets are immediately reachable.
struct WatchWorkoutView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @AppStorage("hcAccentStyle") private var accent = "crimson"
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .center, spacing: 13) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("I M U N")
                                .font(WTheme.label(10))
                                .tracking(3)
                                .foregroundStyle(WTheme.aqua)
                            Text("Make it\ncount.")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .tracking(-0.6)
                                .foregroundStyle(.white)
                            Text(Date().formatted(.dateTime.weekday(.abbreviated).day()))
                                .font(WTheme.label(10)).foregroundStyle(WTheme.muted)
                        }
                        Spacer(minLength: 0)
                        WProgressHalo(
                            completed: store.sets.filter {
                                $0.workoutID == store.workout.id
                            }.count,
                            planned: store.hasScheduledLift ?
                                store.workout.prescribedSetCount : 0)
                    }
                    .padding(.vertical, 9)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(colors:
                                [WTheme.lime.opacity(0.27), WTheme.panel],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    )

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
                Section("TODAY · IPHONE SCHEDULE") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.scheduleState == "ready" ?
                             (store.hasScheduledLift ? store.workout.title : "No lift planned today") :
                             (store.scheduleState == "signedOut" ? "Sign in on iPhone" : "Checking iPhone…"))
                            .font(.system(size: 12, weight: .semibold))
                        Text(store.runPlan?.title ?? "No run scheduled")
                            .font(.system(size: 11)).foregroundStyle(WTheme.muted)
                        if let last = store.scheduleUpdatedAt {
                            Text("Synced " + last.formatted(date: .omitted, time: .shortened))
                                .font(WTheme.label(10)).foregroundStyle(WTheme.aqua)
                        }
                        HStack(spacing: 8) {
                            Button {
                                store.requestCurrentSchedule(manual: true)
                            } label: {
                                Label(store.isRequestingSchedule ? "Checking…" : "Refresh",
                                      systemImage: "arrow.clockwise")
                            }
                            .disabled(store.isRequestingSchedule)
                            Button {
                                store.sendToPhone()
                            } label: {
                                Label("Send to iPhone", systemImage: "iphone.gen3")
                            }
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .buttonStyle(.bordered)
                        .tint(WTheme.aqua)
                        Text(store.status)
                            .font(.system(size: 10))
                            .foregroundStyle(WTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let recovery = store.recoverySummary {
                    Section("RECOVERY SIGNALS") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recovery.source + " · " + recovery.date)
                                .font(WTheme.label(10)).foregroundStyle(WTheme.muted)
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("HRV · RMSSD")
                                        .font(WTheme.label(9)).foregroundStyle(WTheme.muted)
                                    Text(recovery.hrvMS.map { String(format: "%.0f", $0) } ?? "—")
                                        .font(WTheme.metric(23)).foregroundStyle(WTheme.aqua)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("SLEEP")
                                        .font(WTheme.label(9)).foregroundStyle(WTheme.muted)
                                    Text(recovery.sleepSeconds.map {
                                        String(format: "%.1fh", $0 / 3600)
                                    } ?? "—")
                                        .font(WTheme.metric(23)).foregroundStyle(.white)
                                }
                            }
                            Text("See personal baselines and alerts on iPhone.")
                                .font(.system(size: 10)).foregroundStyle(WTheme.muted)
                        }
                        .listRowBackground(WTheme.panel)
                    }
                }
                Section("PREFERENCES") {
                    NavigationLink {
                        WatchPreferences()
                    } label: {
                        Label("APPEARANCE & CONTROLS", systemImage: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
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
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .background(WTheme.bg.ignoresSafeArea())
            .navigationTitle("imun")
        }
        .tint(WTheme.lime)
        .preferredColorScheme(.dark)
        .id(accent)
        .onAppear { store.requestCurrentSchedule() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.requestCurrentSchedule() }
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
            Text("Your completed sets stay saved on the watch and sync to iPhone.")
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
                    Text(store.scheduleState == "ready" ? "REST DAY" : "IPHONE SYNC")
                        .font(WTheme.label()).tracking(1.5)
                        .foregroundStyle(WTheme.aqua)
                    Text(store.scheduleState == "ready" ? "No strength workout scheduled" :
                         "Checking today's workout…")
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                    Text(store.scheduleState == "ready" ?
                         "Your iPhone calendar controls the plan. You can create a workout there." :
                         "Open imun on your iPhone to load the latest schedule.")
                        .font(.system(size: 12)).foregroundStyle(WTheme.muted)
                    WSecondary(title: "REFRESH", symbol: "arrow.clockwise") {
                        store.requestCurrentSchedule(manual: true)
                    }
                    Text(store.status)
                        .font(.system(size: 11))
                        .foregroundStyle(WTheme.muted)
                } else {
                Text("TODAY'S LIFT")
                    .font(WTheme.label()).tracking(1.5)
                    .foregroundStyle(WTheme.aqua)
                Text(store.workout.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(store.workout.exercises.count) movements · \(store.workout.prescribedSetCount) sets")
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
                    Text("No exercises are scheduled. Build a strength plan on iPhone, then sync.")
                        .font(.system(size: 12)).foregroundStyle(WTheme.muted)
                }
                WPrimary(title: "START WORKOUT", symbol: "play.fill") {
                    store.startLifting()
                    if store.liftClock?.isActive == true {
                        health.start(kind: .strength)
                        wHaptic(.start)
                    }
                }
                .disabled(store.workout.exercises.isEmpty || store.runClock?.isActive == true)
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
    @State private var weight = 0.0
    @State private var hasWeight = false
    @State private var reps = 8
    @State private var rir = 2
    @State private var readyHapticSent = false
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
        (current?.id ?? "none") + ":" + String(setCount)
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
                        Text("\(setCount + 1)/\(current.prescribedSets)")
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
                            Color.clear.frame(height: 1)
                                .onChange(of: timeLeft <= 0) { _, finished in
                                    if finished && !readyHapticSent {
                                        readyHapticSent = true
                                        wHaptic(.notification)
                                    }
                                }
                        }
                    } else {
                        quickSetControls(current)
                    }

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

                    // Secondary options are intentionally *below* the critical
                    // editor so the first view remains a one-tap workflow.
                    NavigationLink {
                        WatchMovementPicker()
                    } label: {
                        Label("CHOOSE DIFFERENT EXERCISE", systemImage: "arrow.left.arrow.right")
                            .font(WTheme.label(11))
                    }
                    .disabled(active || otherActive)

                    WQuickEditor(title: "RIR", value: "\(rir)",
                                 decrease: { rir = max(0, rir - 1) },
                                 increase: { rir = min(10, rir + 1) })
                    .padding(.top, 4)
                } else {
                    Text("No unfinished exercises are available.")
                        .foregroundStyle(WTheme.muted)
                }

                NavigationLink {
                    WatchSessionOptions(onFinish: onFinish)
                } label: {
                    Label("PAUSE OR FINISH WORKOUT", systemImage: "slider.horizontal.3")
                        .font(WTheme.label(11))
                }
                .tint(WTheme.muted)
                .padding(.top, 5)
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .background(WTheme.bg.ignoresSafeArea())
        .task(id: nextSetToken) {
            loadNextTargets()
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
            Button {
                if active {
                    let saved = store.stopSet(for: exercise,
                                              weightLb: hasWeight ? weight : nil,
                                              reps: reps, rir: Double(rir))
                    if saved {
                        readyHapticSent = false
                        wHaptic(.success)
                    }
                } else if !otherActive && store.liftClock?.isPaused != true {
                    store.startSet(for: exercise)
                    wHaptic(.start)
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: active ? "checkmark.circle.fill" : "play.fill")
                    Text(active ? "END SET & SAVE" : "START SET \(setCount + 1)")
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
            Text("REST · NEXT SET READY SOON")
                .font(WTheme.label(10))
                .foregroundStyle(WTheme.aqua)
            Text(wClock(seconds))
                .font(WTheme.metric(52))
                .foregroundStyle(WTheme.lime)
            Button {
                store.skipRest()
                readyHapticSent = true
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
            Text("ALL SETS DONE")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
            Text("\(store.guidedCompletedSets) working sets logged")
                .font(.system(size: 12))
                .foregroundStyle(WTheme.muted)
            WPrimary(title: "FINISH WORKOUT", symbol: "flag.checkered",
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
            WPrimary(title: "FINISH WORKOUT", symbol: "flag.checkered",
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
    @AppStorage("hcAccentStyle") private var accent = "crimson"
    @AppStorage("hcWeightIncrement") private var increment = 5.0
    @AppStorage("hcRestOverrideSeconds") private var restOverride = 0
    @AppStorage("hcWatchHaptics") private var haptics = true

    var body: some View {
        List {
            Picker("Accent", selection: $accent) {
                Text("Crimson + White").tag("crimson")
                Text("Performance Lime").tag("lime")
                Text("Ocean Aqua").tag("aqua")
                Text("Minimal White").tag("white")
            }
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
            Toggle("Haptic feedback", isOn: $haptics)
                .tint(WTheme.lime)
            Text("Running voice cues and automatic miles are configured in the Run screen, or in Coach → Settings on iPhone.")
                .font(.caption2).foregroundStyle(WTheme.muted)
        }
        .listStyle(.plain)
        .navigationTitle("Preferences")
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

    private func phase(for elapsed: Double) -> (String, String) {
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
        let next = phase(for: elapsed)
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
                            Text(cueCoach.stage.uppercased())
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
                    WPrimary(title: "FINISH RUN", symbol: "flag.checkered",
                             color: WTheme.amber) { confirmFinish = true }
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
                    Text("Completed runs will appear after syncing Apple Health on iPhone.")
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
