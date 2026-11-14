import SwiftUI

struct PhoneContentView: View {
    @EnvironmentObject private var bridge: PhoneWorkoutBridge
    @State private var email = ""
    @State private var password = ""
    @State private var selectedDate = Date()

    private var recentSets: [HCLoggedSet] {
        bridge.loggedSets.sorted { $0.completedAt > $1.completedAt }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !bridge.signedIn {
                    Section("Health Coach Sign In") {
                        Text("Use the same Command Center account as your Health Coach web app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Email", text: $email)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()

                        SecureField("Password", text: $password)
                            .textContentType(.password)

                        Button("Sign In") {
                            bridge.login(email: email, password: password, date: selectedDate)
                            password = ""
                        }
                        .disabled(bridge.loading || email.isEmpty || password.isEmpty)
                    }
                } else {
                    Section("Training Day") {
                        DatePicker("Workout date", selection: $selectedDate, displayedComponents: .date)
                            .onChange(of: selectedDate) { _, newDate in
                                bridge.refresh(date: newDate)
                            }
                        Button("Go to Today") {
                            selectedDate = Date()
                            bridge.refresh(date: selectedDate)
                        }
                        Button("Refresh from Health Coach") {
                            bridge.refresh(date: selectedDate)
                        }
                        .disabled(bridge.loading)
                    }

                    if let workout = bridge.workout {
                        Section {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(workout.title).font(.title3.bold())
                                Text("\(workout.date) · \(workout.exercises.count) exercises · \(workout.prescribedSetCount) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                bridge.sendToWatch()
                            } label: {
                                Label("Send Workout to Apple Watch", systemImage: "applewatch")
                            }
                            .buttonStyle(.borderedProminent)

                            ForEach(workout.exercises) { exercise in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(exercise.name).font(.body.weight(.semibold))
                                    HStack {
                                        Text("\(exercise.prescribedSets) × \(exercise.repDescription)")
                                        Spacer()
                                        if let weight = exercise.suggestedWeightLb {
                                            Text("Start ~\(weight.formatted()) lb")
                                        } else {
                                            Text("Choose load")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        } header: {
                            Text("Today's Strength")
                        } footer: {
                            Text("Suggested weights come from comparable past logs. No unrecorded weights are invented.")
                        }
                    } else {
                        Section("Workout") {
                            Text("No lifting session scheduled for the selected date.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        HStack {
                            Text("Waiting to upload")
                            Spacer()
                            Text("\(bridge.cloudPendingCount)")
                                .monospacedDigit()
                        }
                        if bridge.cloudPendingCount > 0 {
                            Button("Retry Pending Uploads") {
                                bridge.retryPendingCloudSets()
                            }
                        }
                    } header: {
                        Text("Cloud Sync")
                    } footer: {
                        Text("Watch sets are saved on both devices; the iPhone uploads them when signed in and online.")
                    }

                    Section {
                        Button("Sign Out", role: .destructive) { bridge.logout() }
                    }
                }

                Section("Received from Apple Watch") {
                    if recentSets.isEmpty {
                        Text("Log a set on your watch to see it here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(recentSets.prefix(30))) { set in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(set.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(set.weightLb.map { $0.formatted() + " lb" } ?? "Weight unrecorded") × \(set.reps) reps · \(set.workoutDate)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Status") {
                    if bridge.loading { ProgressView() }
                    Text(bridge.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Health Coach")
        }
    }
}
