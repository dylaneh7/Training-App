import SwiftUI
import WatchKit

private enum WTheme {
    static let bg = Color(red: 0.025, green: 0.047, blue: 0.065)
    static let panel = Color(red: 0.085, green: 0.115, blue: 0.145)
    static let muted = Color(red: 0.61, green: 0.70, blue: 0.73)
    static let lime = Color(red: 0.76, green: 0.98, blue: 0.43)
    static let aqua = Color(red: 0.41, green: 0.85, blue: 0.82)
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
                .foregroundStyle(WTheme.bg)
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

/// A List-based navigation hub fixes the page-gesture / scrolling conflict on
/// watchOS. Large Strength and Run targets are immediately reachable.
struct WatchWorkoutView: View {
    @EnvironmentObject private var store: WatchWorkoutStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("HEALTH COACH")
                            .font(WTheme.label(10))
                            .tracking(2)
                            .foregroundStyle(WTheme.aqua)
                        Text("TRAIN ON YOUR TERMS")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                    }
                    .listRowBackground(WTheme.bg)

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
            .navigationTitle("Health Coach")
        }
        .tint(WTheme.lime)
        .preferredColorScheme(.dark)
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

// MARK: - Strength

private struct WatchStrengthScreen: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession
    @State private var confirmFinish = false

    private var completed: Int {
        store.workout.exercises.reduce(0) { $0 + store.completedSets(for: $1).count }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Text(store.workout.title)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                    Text("\(store.workout.exercises.count) MOVEMENTS")
                        .font(WTheme.label(10)).foregroundStyle(WTheme.muted)
                }
                .listRowBackground(WTheme.bg)

                TimelineView(.periodic(from: .now, by: 1)) { time in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WORKOUT TIME")
                            .font(WTheme.label(10)).foregroundStyle(WTheme.muted)
                        Text(wClock(store.liftClock?.duration(at: time.date) ?? 0))
                            .font(WTheme.metric(37))
                            .foregroundStyle(WTheme.lime)
                        Text("\(completed) / \(store.workout.prescribedSetCount) SETS")
                            .font(WTheme.label(10))
                            .foregroundStyle(WTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowBackground(WTheme.panel)

                if store.liftClock?.isActive == true {
                    if store.liftClock?.isPaused == true {
                        WPrimary(title: "RESUME WORKOUT", symbol: "play.fill") {
                            store.resumeLifting()
                            health.resume()
                        }
                    } else {
                        WSecondary(title: "PAUSE WORKOUT", symbol: "pause.fill") {
                            store.pauseLifting()
                            health.pause()
                        }
                    }
                    WPrimary(title: "FINISH WORKOUT", symbol: "flag.checkered",
                             color: WTheme.amber) {
                        confirmFinish = true
                    }
                    .disabled(store.liftClock?.setStartedAt != nil)
                } else {
                    WPrimary(title: "START WORKOUT", symbol: "play.fill") {
                        store.startLifting()
                        health.start(kind: .strength)
                        WKInterfaceDevice.current().play(.start)
                    }
                }
            }

            Section("EXERCISES · TAP TO LOG") {
                ForEach(store.workout.exercises.indices, id: \.self) { index in
                    let exercise = store.workout.exercises[index]
                    NavigationLink {
                        WatchSetScreen(exercise: exercise)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(String(format: "%02d", index + 1))
                                    .font(WTheme.metric(17))
                                    .foregroundStyle(WTheme.lime)
                                Text(exercise.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .lineLimit(2)
                            }
                            Text("\(store.completedSets(for: exercise).count) / \(exercise.prescribedSets) sets · \(exercise.repDescription) reps")
                                .font(.system(size: 11))
                                .foregroundStyle(WTheme.muted)
                        }
                        .frame(minHeight: 48)
                    }
                    .listRowBackground(WTheme.panel)
                }
                if store.workout.exercises.isEmpty {
                    Text("No exercises scheduled. Build a workout on iPhone.")
                        .foregroundStyle(WTheme.muted)
                }
            }
            Section {
                Text(store.workout.isPreview ?
                     "Preview workout · sync your actual plan from iPhone." : store.status)
                    .font(.system(size: 10))
                    .foregroundStyle(WTheme.muted)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .background(WTheme.bg.ignoresSafeArea())
        .navigationTitle("Strength")
        .confirmationDialog("Finish strength workout?", isPresented: $confirmFinish) {
            Button("Finish & Save") {
                store.endLifting()
                if health.kind == .strength { health.finish() }
                WKInterfaceDevice.current().play(.success)
            }
        }
    }
}

private struct WatchSetScreen: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    let exercise: HCExercise
    @State private var hasWeight = false
    @State private var weight = 0.0
    @State private var reps = 8
    @State private var rir = 2

    private var completed: [HCLoggedSet] { store.completedSets(for: exercise) }
    private var active: Bool {
        store.liftClock?.setExerciseID == exercise.id &&
        store.liftClock?.setStartedAt != nil
    }

    var body: some View {
        List {
            Section {
                Text(exercise.name)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .listRowBackground(WTheme.bg)
                Text("\(exercise.prescribedSets) SETS · \(exercise.repDescription) REPS")
                    .font(WTheme.label(10)).foregroundStyle(WTheme.aqua)
                    .listRowBackground(WTheme.bg)
                if let suggested = exercise.suggestedWeightLb {
                    Text("COACH TARGET · \(suggested.formatted()) LB")
                        .font(WTheme.label(11)).foregroundStyle(WTheme.lime)
                }
            }

            Section("ADJUST YOUR SET") {
                Toggle("Track weight", isOn: $hasWeight)
                    .tint(WTheme.lime)
                    .font(.system(size: 12, weight: .semibold))
                if hasWeight {
                    WStepper(title: "Weight · lb", value: weight.formatted(),
                             minus: { weight = max(0, weight - 5) },
                             plus: { weight = min(1500, weight + 5) })
                }
                WStepper(title: "Reps", value: "\(reps)",
                         minus: { reps = max(1, reps - 1) },
                         plus: { reps = min(60, reps + 1) })
                WStepper(title: "RIR", value: "\(rir)",
                         minus: { rir = max(0, rir - 1) },
                         plus: { rir = min(6, rir + 1) })
            }

            Section("SET TIMER") {
                if store.liftClock?.isActive != true {
                    WPrimary(title: "START WORKOUT", symbol: "play.fill") {
                        store.startLifting()
                    }
                } else if store.liftClock?.isPaused == true {
                    Text("Resume your workout before recording sets.")
                        .font(.caption2).foregroundStyle(WTheme.muted)
                } else if active {
                    TimelineView(.periodic(from: .now, by: 1)) { now in
                        VStack(alignment: .leading, spacing: 7) {
                            Text("SET IN PROGRESS")
                                .font(WTheme.label(10))
                                .foregroundStyle(WTheme.amber)
                            Text(wClock(now.date.timeIntervalSince(
                                store.liftClock?.setStartedAt ?? now.date)))
                                .font(WTheme.metric(38))
                        }
                    }
                    WPrimary(title: "STOP & SAVE", symbol: "checkmark.circle.fill",
                             color: WTheme.amber) {
                        let saved = store.stopSet(for: exercise,
                                                  weightLb: hasWeight ? weight : nil,
                                                  reps: reps, rir: Double(rir))
                        if saved { WKInterfaceDevice.current().play(.success) }
                    }
                    WSecondary(title: "CANCEL SET", symbol: "xmark") { store.cancelSet() }
                } else if store.liftClock?.setStartedAt != nil {
                    Text("Finish the other active exercise set.")
                        .font(.caption2).foregroundStyle(WTheme.muted)
                } else {
                    WPrimary(title: "START SET \(completed.count + 1)", symbol: "play.fill") {
                        store.startSet(for: exercise)
                        WKInterfaceDevice.current().play(.start)
                    }
                }
                if let until = store.liftClock?.restEndsAt {
                    TimelineView(.periodic(from: .now, by: 1)) { now in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("REST REMAINING")
                                .font(WTheme.label(10)).foregroundStyle(WTheme.aqua)
                            Text(wClock(max(0, until.timeIntervalSince(now.date))))
                                .font(WTheme.metric(35))
                            WSecondary(title: "SKIP REST", symbol: "forward.end.fill") {
                                store.skipRest()
                            }
                        }
                    }
                }
            }

            Section("SAVED SETS") {
                ForEach(completed) { set in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(WTheme.lime)
                        Text("SET \(set.index)").font(WTheme.label(11))
                        Spacer()
                        Text("\(set.weightLb?.formatted() ?? "—") × \(set.reps)")
                            .font(WTheme.metric(17))
                    }
                }
                if completed.isEmpty {
                    Text("Your recorded sets will appear here.")
                        .foregroundStyle(WTheme.muted)
                }
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .background(WTheme.bg.ignoresSafeArea())
        .navigationTitle("Set")
        .onAppear {
            reps = exercise.repMin
            if let suggested = exercise.suggestedWeightLb {
                weight = suggested
                hasWeight = true
            }
        }
    }
}

// MARK: - Running and imported run history

private struct WatchRunScreen: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession
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
                        Text("Sync your planned run from the iPhone app.")
                            .font(.system(size: 12)).foregroundStyle(WTheme.muted)
                    }
                }
                .listRowBackground(WTheme.panel)
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
                        WKInterfaceDevice.current().play(.click)
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
                        WKInterfaceDevice.current().play(.start)
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
        .confirmationDialog("Finish run?", isPresented: $confirmFinish) {
            Button("Finish & Save") {
                store.finishRun(distanceMeters: health.distanceMeters,
                                heartRateBPM: health.averageHeartRateBPM)
                if health.kind == .run { health.finish() }
                WKInterfaceDevice.current().play(.success)
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
