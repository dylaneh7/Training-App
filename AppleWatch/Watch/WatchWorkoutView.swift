import SwiftUI
import WatchKit

private func clockText(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    return String(format: "%02d:%02d", total / 60, total % 60)
}

struct WatchWorkoutView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession

    var body: some View {
        TabView {
            NavigationStack {
                List {
                    Section {
                        Text(store.workout.title).font(.headline)
                        Text("\(store.workout.exercises.count) exercises · \(store.workout.prescribedSetCount) work sets")
                            .font(.caption2).foregroundStyle(.secondary)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            VStack(alignment: .leading) {
                                Text(clockText(store.liftClock?.duration(at: context.date) ?? 0))
                                    .font(.title2.monospacedDigit().bold())
                                if let bpm = health.heartRateBPM, health.kind == .strength {
                                    Text("\(Int(bpm.rounded())) bpm").foregroundStyle(.red)
                                }
                            }
                        }
                        if store.liftClock?.isActive == true {
                            if store.liftClock?.isPaused == true {
                                Button("Resume Workout") {
                                    store.resumeLifting()
                                    health.resume()
                                }
                            } else {
                                Button("Pause Workout") {
                                    store.pauseLifting()
                                    health.pause()
                                }
                            }
                            Button("Finish Workout", role: .destructive) {
                                store.endLifting()
                                if health.kind == .strength { health.finish() }
                            }
                            .disabled(store.liftClock?.setStartedAt != nil)
                        } else {
                            Button("Start Workout") {
                                store.startLifting()
                                health.start(kind: .strength)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        if store.workout.isPreview {
                            Text("Preview program. Sync iPhone for your actual plan.")
                                .font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    Section("Exercises") {
                        ForEach(store.workout.exercises) { exercise in
                            NavigationLink {
                                WatchExerciseView(exercise: exercise)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        Text("\(store.completedSets(for: exercise).count)/\(exercise.prescribedSets) sets")
                                        Spacer()
                                        Text(exercise.repDescription)
                                    }
                                    .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Text(store.status).font(.caption2).foregroundStyle(.secondary)
                }
                .navigationTitle("Strength")
            }
            NavigationStack { WatchRunView() }
                .tabItem { Label("Run", systemImage: "figure.run") }
        }
        .tabViewStyle(.page)
    }
}

private struct WatchExerciseView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    let exercise: HCExercise
    @State private var weightLb = 0.0
    @State private var hasWeight = false
    @State private var reps = 8
    @State private var rir = 2

    private var completed: [HCLoggedSet] { store.completedSets(for: exercise) }
    private var active: Bool {
        store.liftClock?.setExerciseID == exercise.id &&
        store.liftClock?.setStartedAt != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                Text(exercise.name).font(.headline)
                Text("\(exercise.prescribedSets) sets × \(exercise.repDescription) reps")
                    .font(.caption).foregroundStyle(.secondary)
                if let suggestion = exercise.suggestedWeightLb {
                    Text("Suggested ~\(suggestion.formatted()) lb")
                        .font(.caption).foregroundStyle(.green)
                }

                Toggle("Use weight", isOn: $hasWeight).font(.caption)
                if hasWeight {
                    Stepper(value: $weightLb, in: 0...1500, step: 5) {
                        Text("\(weightLb.formatted()) lb").font(.headline)
                    }
                }
                Stepper(value: $reps, in: 1...60) {
                    Text("\(reps) reps").font(.headline)
                }
                Stepper(value: $rir, in: 0...6) {
                    Text("\(rir) reps in reserve").font(.caption)
                }

                if store.liftClock?.isActive != true {
                    Button("Start Overall Workout") { store.startLifting() }
                        .buttonStyle(.borderedProminent)
                } else if store.liftClock?.isPaused == true {
                    Text("Resume overall workout first").font(.caption2)
                } else if active {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("Set: \(clockText(context.date.timeIntervalSince(store.liftClock?.setStartedAt ?? context.date)))")
                            .font(.headline.monospacedDigit())
                    }
                    Button("Stop & Save Set \(completed.count + 1)") {
                        if store.stopSet(for: exercise, weightLb: hasWeight ? weightLb : nil,
                                         reps: reps, rir: Double(rir)) {
                            WKInterfaceDevice.current().play(.success)
                        }
                    }
                    .tint(.orange)
                    Button("Cancel Set", role: .destructive) { store.cancelSet() }
                } else if store.liftClock?.setStartedAt != nil {
                    Text("Finish the active set before starting another.")
                        .font(.caption2)
                } else {
                    Button("Start Set \(completed.count + 1)") {
                        store.startSet(for: exercise)
                        WKInterfaceDevice.current().play(.start)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let end = store.liftClock?.restEndsAt {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, end.timeIntervalSince(context.date))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(remaining > 0 ? "Rest \(clockText(remaining))" : "Rest complete")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(remaining > 0 ? Color.secondary : Color.green)
                            if remaining > 0 {
                                Button("Skip Rest") { store.skipRest() }
                            }
                        }
                    }
                }

                ForEach(completed) { set in
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("\(set.weightLb.map { $0.formatted() + " lb" } ?? "No load") × \(set.reps)")
                        if let seconds = set.durationSeconds {
                            Text(clockText(seconds)).foregroundStyle(.secondary)
                        }
                    }.font(.caption2)
                }
            }.padding(.horizontal, 5)
        }
        .navigationTitle("Set Editor")
        .onAppear {
            if let target = exercise.suggestedWeightLb {
                hasWeight = true
                weightLb = target
            }
            reps = exercise.repMin
        }
    }
}

private struct WatchRunView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession

    var body: some View {
        List {
            Section {
                Text(store.runPlan?.title ?? "Run")
                    .font(.headline)
                Text(store.runPlan?.notes ?? "Start a run from your watch or load today's plan from iPhone.")
                    .font(.caption).foregroundStyle(.secondary)
                if let miles = store.runPlan?.targetDistanceMiles {
                    Text("Target \(miles.formatted()) miles").font(.headline)
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(clockText(store.runClock?.duration(at: context.date) ?? 0))
                        .font(.title2.monospacedDigit().bold())
                }
                if let meters = health.distanceMeters {
                    Text(String(format: "%.2f miles", meters / 1609.344))
                }
                if let bpm = health.heartRateBPM, health.kind == .run {
                    Text("\(Int(bpm.rounded())) bpm").foregroundStyle(.red)
                }

                if store.runClock?.isActive == true {
                    if store.runClock?.isPaused == true {
                        Button("Resume Run") {
                            store.resumeRun()
                            health.resume()
                        }
                    } else {
                        Button("Pause Run") {
                            store.pauseRun()
                            health.pause()
                        }
                    }
                    Button("Finish Run", role: .destructive) {
                        store.finishRun(distanceMeters: health.distanceMeters,
                                        heartRateBPM: health.averageHeartRateBPM)
                        if health.kind == .run { health.finish() }
                    }
                } else {
                    Button("Start Run") {
                        store.startRun()
                        health.start(kind: .run)
                    }.buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Run")
    }
}
