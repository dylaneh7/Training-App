import SwiftUI
import WatchKit

private enum WTheme {
    static let bg = Color(red: 0.025, green: 0.047, blue: 0.065)
    static let panel = Color(red: 0.085, green: 0.115, blue: 0.145)
    static let secondary = Color(red: 0.61, green: 0.70, blue: 0.73)
    static let lime = Color(red: 0.76, green: 0.98, blue: 0.43)
    static let aqua = Color(red: 0.41, green: 0.85, blue: 0.82)
    static let orange = Color(red: 1.0, green: 0.7, blue: 0.35)
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }
    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}

private func watchElapsed(_ sec: TimeInterval) -> String {
    let t = max(0, Int(sec))
    return String(format: "%02d:%02d", t / 60, t % 60)
}

private struct WatchPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WTheme.panel, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct WatchPrimary: View {
    let title: String
    let symbol: String
    var color: Color = WTheme.lime
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(WTheme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color, in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }
}

private struct WatchSecondary: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(WTheme.panel, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct WatchWorkoutView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession

    var body: some View {
        TabView {
            NavigationStack { WatchStrengthDashboard() }
                .tabItem { Label("Strength", systemImage: "dumbbell.fill") }
            NavigationStack { WatchRunDashboard() }
                .tabItem { Label("Run", systemImage: "figure.run") }
        }
        .tabViewStyle(.page)
        .tint(WTheme.lime)
        .preferredColorScheme(.dark)
    }
}

private struct WatchStrengthDashboard: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession
    @State private var confirmFinish = false

    private var completed: Int {
        store.workout.exercises.reduce(0) { $0 + store.completedSets(for: $1).count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                Text("HEALTH COACH / STRENGTH")
                    .font(WTheme.label(9))
                    .tracking(1.4)
                    .foregroundStyle(WTheme.aqua)
                Text(store.workout.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .lineLimit(2)
                WatchPanel {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Label("WORKOUT TIME", systemImage: "timer")
                                .font(WTheme.label(9))
                                .foregroundStyle(WTheme.secondary)
                            Spacer()
                            if let bpm = health.heartRateBPM, health.kind == .strength {
                                Text("\(Int(bpm)) BPM")
                                    .font(WTheme.label(10))
                                    .foregroundStyle(WTheme.aqua)
                            }
                        }
                        TimelineView(.periodic(from: .now, by: 1)) { time in
                            Text(watchElapsed(store.liftClock?.duration(at: time.date) ?? 0))
                                .font(WTheme.number(34))
                                .foregroundStyle(WTheme.lime)
                        }
                        Text("\(completed) / \(store.workout.prescribedSetCount) WORK SETS")
                            .font(WTheme.label(10))
                            .foregroundStyle(WTheme.secondary)
                    }
                }
                if store.liftClock?.isActive == true {
                    if store.liftClock?.isPaused == true {
                        WatchPrimary(title: "RESUME", symbol: "play.fill") {
                            store.resumeLifting()
                            health.resume()
                        }
                    } else {
                        WatchSecondary(title: "Pause workout", symbol: "pause.fill") {
                            store.pauseLifting()
                            health.pause()
                        }
                    }
                    WatchSecondary(title: "Finish workout", symbol: "flag.checkered") {
                        confirmFinish = true
                    }
                    .disabled(store.liftClock?.setStartedAt != nil)
                } else {
                    WatchPrimary(title: "START WORKOUT", symbol: "play.fill") {
                        store.startLifting()
                        health.start(kind: .strength)
                        WKInterfaceDevice.current().play(.start)
                    }
                }
                if store.workout.isPreview {
                    Text("PREVIEW · SYNC PHONE FOR YOUR PLAN")
                        .font(WTheme.label(9))
                        .foregroundStyle(WTheme.orange)
                }
                Text("EXERCISES")
                    .font(WTheme.label(10))
                    .tracking(1.5)
                    .foregroundStyle(WTheme.secondary)
                    .padding(.top, 4)
                ForEach(Array(store.workout.exercises.enumerated()), id: \.element.id) { i, exercise in
                    NavigationLink {
                        WatchSetDashboard(exercise: exercise)
                    } label: {
                        HStack(spacing: 10) {
                            Text(String(format: "%02d", i+1))
                                .font(WTheme.number(16))
                                .foregroundStyle(WTheme.lime)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .lineLimit(2)
                                Text("\(store.completedSets(for: exercise).count)/\(exercise.prescribedSets) sets  ·  \(exercise.repDescription) reps")
                                    .font(.system(size: 10))
                                    .foregroundStyle(WTheme.secondary)
                            }
                            Spacer(minLength: 1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(WTheme.secondary)
                        }
                        .padding(11)
                        .background(WTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                if store.workout.exercises.isEmpty {
                    Text("REST DAY · NO LIFTING PROGRAM")
                        .font(WTheme.label(10))
                        .foregroundStyle(WTheme.secondary)
                }
                Text(store.status)
                    .font(.system(size: 9))
                    .foregroundStyle(WTheme.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 18)
        }
        .background(WTheme.bg.ignoresSafeArea())
        .navigationTitle("Strength")
        .confirmationDialog("Finish strength workout?", isPresented: $confirmFinish) {
            Button("Finish & Save") {
                store.endLifting()
                if health.kind == .strength { health.finish() }
                WKInterfaceDevice.current().play(.success)
            }
        } message: {
            Text("Saved sets remain on your watch and will sync with your iPhone.")
        }
    }
}

private struct WatchSetDashboard: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    let exercise: HCExercise
    @State private var hasWeight = false
    @State private var weight = 0.0
    @State private var reps = 8
    @State private var rir = 2

    private var completed: [HCLoggedSet] { store.completedSets(for: exercise) }
    private var isActive: Bool {
        store.liftClock?.setExerciseID == exercise.id &&
        store.liftClock?.setStartedAt != nil
    }
    private var anotherActive: Bool {
        store.liftClock?.setStartedAt != nil && !isActive
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                Text("EXERCISE / \(completed.count + 1)")
                    .font(WTheme.label(9))
                    .tracking(1.3)
                    .foregroundStyle(WTheme.aqua)
                Text(exercise.name)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(exercise.prescribedSets) sets × \(exercise.repDescription) reps")
                    .font(.system(size: 11))
                    .foregroundStyle(WTheme.secondary)
                if let target = exercise.suggestedWeightLb {
                    Text("COACH  ·  \(target.formatted()) LB\(exercise.name.lowercased().contains("dumbbell") ? " / DB" : "")")
                        .font(WTheme.label(10))
                        .foregroundStyle(WTheme.lime)
                }
                WatchPanel {
                    VStack(spacing: 9) {
                        Toggle("Record load", isOn: $hasWeight)
                            .font(.system(size: 12, weight: .semibold))
                            .tint(WTheme.lime)
                        if hasWeight {
                            numberRow(label: "LB", value: weight.formatted(),
                                      minus: { weight = max(0, weight - 5) },
                                      plus: { weight = min(1500, weight + 5) })
                        }
                        numberRow(label: "REPS", value: "\(reps)",
                                  minus: { reps = max(1, reps - 1) },
                                  plus: { reps = min(60, reps + 1) })
                        numberRow(label: "RIR", value: "\(rir)",
                                  minus: { rir = max(0, rir - 1) },
                                  plus: { rir = min(6, rir + 1) })
                    }
                }
                if store.liftClock?.isActive != true {
                    WatchPrimary(title: "START WORKOUT", symbol: "play.fill") {
                        store.startLifting()
                    }
                } else if store.liftClock?.isPaused == true {
                    Text("Resume the overall workout first.")
                        .font(.caption2).foregroundStyle(WTheme.secondary)
                } else if isActive {
                    WatchPanel {
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SET IN PROGRESS")
                                    .font(WTheme.label(9))
                                    .foregroundStyle(WTheme.orange)
                                Text(watchElapsed(
                                    timeline.date.timeIntervalSince(store.liftClock?.setStartedAt ?? timeline.date)))
                                    .font(WTheme.number(32))
                            }
                        }
                    }
                    WatchPrimary(title: "STOP & SAVE", symbol: "checkmark",
                                 color: WTheme.orange) {
                        if store.stopSet(for: exercise, weightLb: hasWeight ? weight : nil,
                                         reps: reps, rir: Double(rir)) {
                            WKInterfaceDevice.current().play(.success)
                        }
                    }
                    WatchSecondary(title: "Cancel active set", symbol: "xmark") {
                        store.cancelSet()
                    }
                } else if anotherActive {
                    Text("Finish the active set in the other exercise first.")
                        .font(.caption2).foregroundStyle(WTheme.secondary)
                } else {
                    WatchPrimary(title: "START SET \(completed.count + 1)", symbol: "play.fill") {
                        store.startSet(for: exercise)
                        WKInterfaceDevice.current().play(.start)
                    }
                }
                if let until = store.liftClock?.restEndsAt {
                    WatchRestCountdown(end: until) {
                        store.skipRest()
                    }
                }
                if !completed.isEmpty {
                    Text("RECORDED SETS")
                        .font(WTheme.label(10))
                        .foregroundStyle(WTheme.secondary)
                    ForEach(completed) { item in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(WTheme.lime)
                            Text("\(item.weightLb?.formatted() ?? "—") lb × \(item.reps)")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text(item.durationSeconds.map(watchElapsed) ?? "")
                                .font(WTheme.number(11))
                                .foregroundStyle(WTheme.secondary)
                        }
                        .padding(9)
                        .background(WTheme.panel, in: RoundedRectangle(cornerRadius: 11))
                    }
                }
                if let instructions = exercise.instructions {
                    Text(instructions)
                        .font(.system(size: 11))
                        .foregroundStyle(WTheme.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 16)
        }
        .background(WTheme.bg.ignoresSafeArea())
        .navigationTitle("Set Editor")
        .onAppear {
            reps = exercise.repMin
            if let target = exercise.suggestedWeightLb {
                weight = target
                hasWeight = true
            }
        }
    }

    @ViewBuilder
    private func numberRow(label: String, value: String,
                           minus: @escaping () -> Void,
                           plus: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: minus) {
                Image(systemName: "minus")
                    .frame(width: 34, height: 32)
                    .background(WTheme.bg, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Decrease \(label)")
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text(label).font(WTheme.label(9)).foregroundStyle(WTheme.secondary)
                Text(value).font(WTheme.number(23))
            }
            Spacer(minLength: 0)
            Button(action: plus) {
                Image(systemName: "plus")
                    .frame(width: 34, height: 32)
                    .background(WTheme.bg, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Increase \(label)")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

private struct WatchRestCountdown: View {
    let end: Date
    let skip: () -> Void
    @State private var notified = false

    var body: some View {
        WatchPanel {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let remaining = max(0, Int(end.timeIntervalSince(timeline.date)))
                VStack(alignment: .leading, spacing: 7) {
                    Text(remaining > 0 ? "RECOVER / REST" : "REST COMPLETE")
                        .font(WTheme.label(10))
                        .foregroundStyle(remaining > 0 ? WTheme.aqua : WTheme.lime)
                    Text(watchElapsed(Double(remaining)))
                        .font(WTheme.number(31))
                    if remaining > 0 {
                        WatchSecondary(title: "Skip rest", symbol: "forward.end.fill",
                                       action: skip)
                    }
                }
                .onChange(of: remaining) { _, value in
                    if value == 0 && !notified {
                        notified = true
                        WKInterfaceDevice.current().play(.notification)
                    }
                }
            }
        }
    }
}

private struct WatchRunDashboard: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession
    @State private var confirmFinish = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("HEALTH COACH / ENDURANCE")
                    .font(WTheme.label(9))
                    .tracking(1.3)
                    .foregroundStyle(WTheme.aqua)
                Text(store.runPlan?.title ?? "FREE RUN")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                if let miles = store.runPlan?.targetDistanceMiles {
                    Text("TARGET  ·  \(miles.formatted()) MI")
                        .font(WTheme.label(10))
                        .foregroundStyle(WTheme.aqua)
                }
                WatchPanel {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ELAPSED")
                            .font(WTheme.label(9))
                            .foregroundStyle(WTheme.secondary)
                        TimelineView(.periodic(from: .now, by: 1)) { time in
                            Text(watchElapsed(store.runClock?.duration(at: time.date) ?? 0))
                                .font(WTheme.number(34))
                                .foregroundStyle(WTheme.aqua)
                        }
                        HStack {
                            VStack(alignment: .leading) {
                                Text("DISTANCE").font(WTheme.label(9))
                                    .foregroundStyle(WTheme.secondary)
                                Text(health.distanceMeters.map {
                                    String(format: "%.2f mi", $0 / 1609.344)
                                } ?? "—")
                                .font(WTheme.number(19))
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("HEART RATE").font(WTheme.label(9))
                                    .foregroundStyle(WTheme.secondary)
                                Text(health.heartRateBPM.map {
                                    "\(Int($0)) bpm"
                                } ?? "—")
                                .font(WTheme.number(17))
                            }
                        }
                    }
                }
                if store.runClock?.isActive == true {
                    if store.runClock?.isPaused == true {
                        WatchPrimary(title: "RESUME RUN", symbol: "play.fill",
                                     color: WTheme.aqua) {
                            store.resumeRun()
                            health.resume()
                        }
                    } else {
                        WatchSecondary(title: "Pause run", symbol: "pause.fill") {
                            store.pauseRun()
                            health.pause()
                        }
                    }
                    WatchPrimary(title: "SAVE SPLIT", symbol: "flag.fill", color: WTheme.aqua) {
                        store.addRunSplit(currentDistanceMeters: health.distanceMeters)
                        WKInterfaceDevice.current().play(.click)
                    }
                    WatchSecondary(title: "Finish run", symbol: "flag.checkered") {
                        confirmFinish = true
                    }
                } else {
                    WatchPrimary(title: "START RUN", symbol: "play.fill",
                                 color: WTheme.aqua) {
                        store.startRun()
                        health.start(kind: .run)
                        WKInterfaceDevice.current().play(.start)
                    }
                }
                if let splits = store.runClock?.splits, !splits.isEmpty {
                    Text("SPLITS").font(WTheme.label(10))
                        .foregroundStyle(WTheme.secondary)
                    ForEach(splits) { split in
                        HStack {
                            Text("LAP \(split.index)")
                            Spacer()
                            Text(watchElapsed(split.elapsedSeconds))
                                .font(WTheme.number(15))
                        }
                        .font(.system(size: 11))
                        .padding(10)
                        .background(WTheme.panel, in: RoundedRectangle(cornerRadius: 11))
                    }
                }
                Text(store.runPlan?.notes ?? "Start a run or sync today's running plan from iPhone.")
                    .font(.system(size: 11))
                    .foregroundStyle(WTheme.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 17)
        }
        .background(WTheme.bg.ignoresSafeArea())
        .navigationTitle("Run")
        .confirmationDialog("Finish running?", isPresented: $confirmFinish) {
            Button("Finish & Save") {
                store.finishRun(distanceMeters: health.distanceMeters,
                                heartRateBPM: health.averageHeartRateBPM)
                if health.kind == .run { health.finish() }
                WKInterfaceDevice.current().play(.success)
            }
        }
    }
}
