import SwiftUI

struct PhoneContentView: View {
    @EnvironmentObject private var bridge: PhoneWorkoutBridge

    var body: some View {
        NavigationStack {
            List {
                Section("Workout on Your Watch") {
                    Text(HCWorkout.preview.title)
                        .font(.headline)
                    Text("\(HCWorkout.preview.exercises.count) exercises · 21 prescribed working sets")
                        .foregroundStyle(.secondary)
                    Button("Send Demo Workout to Watch") {
                        bridge.sendDemoWorkout()
                    }
                }

                Section("Logged Sets Received") {
                    if bridge.loggedSets.isEmpty {
                        Text("Sets logged on Apple Watch appear here after syncing.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(bridge.loggedSets.sorted(by: { $0.completedAt > $1.completedAt })) { set in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(set.exerciseID.capitalized)
                                Text("\(set.weightLb.formatted()) lb × \(set.reps) reps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Connection") {
                    Text(bridge.status).font(.footnote)
                }
            }
            .navigationTitle("Health Coach")
        }
    }
}
