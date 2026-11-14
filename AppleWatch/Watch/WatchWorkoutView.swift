import SwiftUI
import WatchKit

struct WatchWorkoutView: View {
    @EnvironmentObject private var store: WatchWorkoutStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(store.workout.title)
                        .font(.headline)
                    Text("Workout date: \(store.workout.date)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(store.workout.exercises) { exercise in
                    NavigationLink {
                        WatchExerciseView(exercise: exercise)
                            .environmentObject(store)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.subheadline)
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
            }
            .navigationTitle("Health Coach")
        }
    }
}

private struct WatchExerciseView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    let exercise: HCExercise

    @State private var weightLb: Double = 0
    @State private var reps: Int = 8

    private var completed: [HCLoggedSet] { store.completedSets(for: exercise) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(exercise.name).font(.headline)
                Text("Target: \(exercise.prescribedSets) × \(exercise.repDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let suggested = exercise.suggestedWeightLb {
                    Text("Suggested: \(suggested.formatted()) lb")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("No verified weight suggestion yet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Stepper(value: $weightLb, in: 0...1000, step: 5) {
                    Text("Weight: \(weightLb.formatted()) lb")
                        .font(.subheadline)
                }

                Stepper(value: $reps, in: 1...40) {
                    Text("Reps: \(reps)").font(.subheadline)
                }

                Button("Log Set \(completed.count + 1)") {
                    store.log(exercise: exercise, weightLb: weightLb, reps: reps)
                    WKInterfaceDevice.current().play(.success)
                }
                .buttonStyle(.borderedProminent)

                ForEach(completed) { set in
                    Label("\(set.weightLb.formatted()) lb × \(set.reps)", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("Log Set")
        .onAppear {
            weightLb = exercise.suggestedWeightLb ?? 0
            reps = exercise.repMin
        }
    }
}
