import SwiftUI
import WatchKit

struct WatchWorkoutView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthSession

    private var totalDone: Int {
        store.workout.exercises.reduce(0) { $0 + store.completedSets(for: $1).count }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.workout.title)
                            .font(.headline)
                        Text("\(totalDone) / \(store.workout.prescribedSetCount) working sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if store.workout.isPreview {
                            Label("Demo — connect iPhone for live plan", systemImage: "iphone")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Apple Fitness") {
                    HStack {
                        if let bpm = health.heartRateBPM {
                            Label("\(Int(bpm.rounded())) bpm", systemImage: "heart.fill")
                                .foregroundStyle(.red)
                        } else {
                            Label("Heart rate —", systemImage: "heart")
                        }
                    }
                    if health.isRunning {
                        Button("End & Save Workout", role: .destructive) { health.finish() }
                    } else {
                        Button("Start Strength Workout") { health.start() }
                    }
                    Text(health.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("Today's Exercises") {
                    ForEach(store.workout.exercises) { exercise in
                        NavigationLink {
                            WatchExerciseView(exercise: exercise)
                                .environmentObject(store)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                HStack {
                                    Text("\(store.completedSets(for: exercise).count)/\(exercise.prescribedSets) sets")
                                    Spacer()
                                    Text("\(exercise.repDescription) reps")
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if store.workout.exercises.isEmpty {
                        Text("Rest day · No scheduled strength training")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(store.status).font(.caption2).foregroundStyle(.secondary)
            }
            .navigationTitle("Health Coach")
        }
    }
}

private struct WatchExerciseView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    let exercise: HCExercise

    @State private var useWeight = false
    @State private var weightLb: Double = 0
    @State private var reps = 8
    @State private var rir = 2
    @State private var restUntil: Date?

    private var completed: [HCLoggedSet] { store.completedSets(for: exercise) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(exercise.name)
                    .font(.headline)

                Text("Plan: \(exercise.prescribedSets) × \(exercise.repDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let suggested = exercise.suggestedWeightLb {
                    Text("Suggested load: ~\(suggested.formatted()) lb")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("Load not recorded previously — select your weight")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Toggle("Record weight", isOn: $useWeight)
                    .font(.caption)

                if useWeight {
                    Stepper(value: $weightLb, in: 0...1500, step: 5) {
                        Text("\(weightLb.formatted()) lb")
                            .font(.headline)
                    }
                }

                Stepper(value: $reps, in: 1...50) {
                    Text("\(reps) reps").font(.headline)
                }

                Stepper(value: $rir, in: 0...5) {
                    Text("\(rir) RIR").font(.caption)
                }

                Button("Log Set \(completed.count + 1)") {
                    store.log(exercise: exercise,
                              weightLb: useWeight ? weightLb : nil,
                              reps: reps,
                              rir: Double(rir))
                    restUntil = Date().addingTimeInterval(TimeInterval(exercise.restSeconds))
                    WKInterfaceDevice.current().play(.success)
                }
                .buttonStyle(.borderedProminent)

                if let restUntil {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        let remaining = max(0, Int(restUntil.timeIntervalSince(timeline.date)))
                        Text(remaining == 0 ? "Rest complete ✓" : "Rest: \(remaining) sec")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(remaining == 0 ? .green : .secondary)
                    }
                }

                if !completed.isEmpty {
                    Divider()
                    ForEach(completed) { set in
                        Label("\(set.weightLb.map { $0.formatted() + " lb" } ?? "— lb") × \(set.reps)", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 5)
        }
        .navigationTitle("Record Set")
        .onAppear {
            if let suggested = exercise.suggestedWeightLb {
                useWeight = true
                weightLb = suggested
            }
            reps = exercise.repMin
        }
    }
}
