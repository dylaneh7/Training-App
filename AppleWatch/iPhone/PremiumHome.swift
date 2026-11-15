import SwiftUI
import Charts

// MARK: - Health Coach 2.0 navigation

struct PremiumHomeView: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @State private var selectedDate = Date()
    @StateObject private var appleHealth = HCAppleHealthReader()

    var body: some View {
        TabView {
            NavigationStack { PremiumStrengthPage(date: $selectedDate) }
                .tabItem { Label("Strength", systemImage: "dumbbell.fill") }
            NavigationStack { PremiumRunPage(date: $selectedDate) }
                .tabItem { Label("Run", systemImage: "figure.run") }
            NavigationStack { PremiumProgressPage() }
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
            NavigationStack { PremiumRecoveryPage(appleHealth: appleHealth) }
                .tabItem { Label("Recovery", systemImage: "waveform.path.ecg") }
            NavigationStack { PremiumCoachPage() }
                .tabItem { Label("Coach", systemImage: "bubble.left.and.text.bubble.right") }
        }
        .tint(HCDesign.electric)
        .preferredColorScheme(.dark)
        .onChange(of: selectedDate) { _, value in coach.refresh(date: value) }
        .onAppear {
            if coach.signedIn && coach.workout == nil { coach.refresh(date: selectedDate) }
            configureTabAppearance()
        }
    }

    private func configureTabAppearance() {
        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(HCDesign.canvas)
        bar.stackedLayoutAppearance.normal.iconColor = UIColor(HCDesign.secondary)
        bar.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(HCDesign.secondary)]
        bar.stackedLayoutAppearance.selected.iconColor = UIColor(HCDesign.electric)
        bar.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(HCDesign.electric)]
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar
    }
}

private struct PremiumHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var badge: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(eyebrow.uppercased())
                    .font(HCDesign.label())
                    .tracking(2.3)
                    .foregroundStyle(HCDesign.aqua)
                Spacer()
                if let badge { HCAccentTag(title: badge) }
            }
            Text(title)
                .font(HCDesign.display(34))
                .tracking(-1.5)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .foregroundStyle(HCDesign.ink)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HCDesign.secondary)
        }
        .padding(.top, 13)
    }
}

private struct PremiumDatePicker: View {
    @Binding var date: Date
    var body: some View {
        HStack {
            Label("TRAINING DATE", systemImage: "calendar")
                .font(HCDesign.label(11))
                .tracking(1.2)
                .foregroundStyle(HCDesign.secondary)
            Spacer()
            DatePicker("Workout day", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(HCDesign.electric)
                .fixedSize()
                .accessibilityLabel("Select training day")
        }
        .padding(12)
        .background(HCDesign.card, in: RoundedRectangle(cornerRadius: 15))
    }
}

private struct PremiumLogin: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        HCCard(accent: HCDesign.aqua) {
            VStack(alignment: .leading, spacing: 15) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(HCDesign.aqua)
                Text("YOUR TRAINING. CONNECTED.")
                    .font(HCDesign.display(21))
                Text("Sign in with your Health Coach / Command Center account. Your lifting history and planned runs stay in sync.")
                    .font(.subheadline)
                    .foregroundStyle(HCDesign.secondary)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(HCDesign.raised, in: RoundedRectangle(cornerRadius: 12))
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding(14)
                    .background(HCDesign.raised, in: RoundedRectangle(cornerRadius: 12))
                HCFilledButton(title: "Connect Health Coach", icon: "arrow.right",
                               disabled: email.isEmpty || password.isEmpty || coach.loading) {
                    coach.login(email: email, password: password, date: Date())
                    password = ""
                }
                Text(coach.status).font(.caption2).foregroundStyle(HCDesign.secondary)
            }
        }
    }
}

private struct PremiumStrengthPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Binding var date: Date
    @AppStorage("hcAggressiveProgression") private var aggressive = true
    @State private var showEditor = false
    @State private var showNew = false
    @State private var newTitle = "Full Body Strength"

    private var plan: HCWorkout? { coach.workout }
    private var doneSets: [HCLoggedSet] {
        guard let plan else { return [] }
        return coach.loggedSets.filter { $0.workoutID == plan.id }
    }
    private var volume: Double {
        doneSets.reduce(0) { $0 + ($1.weightLb ?? 0) * Double($1.reps) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                PremiumHeader(eyebrow: "PERFORMANCE / STRENGTH",
                              title: "Own the session.",
                              subtitle: "Track every rep. Make every set count.",
                              badge: aggressive ? "SMART PROGRESSION" : "CONTROLLED")
                PremiumDatePicker(date: $date)
                HCSyncStatus(pending: coach.cloudPendingCount,
                             saving: coach.savingPlan, connected: coach.signedIn)

                if !coach.signedIn { PremiumLogin() }

                if let plan {
                    HCCard(accent: HCDesign.electric) {
                        VStack(alignment: .leading, spacing: 17) {
                            HCAccentTag(title: "TODAY'S PROGRAM", color: HCDesign.electric)
                            Text(plan.title)
                                .font(HCDesign.display(29))
                                .tracking(-0.8)
                            Text("\(plan.exercises.count) movements  /  \(plan.prescribedSetCount) working sets")
                                .font(.subheadline).foregroundStyle(HCDesign.secondary)

                            HStack(spacing: 7) {
                                HCMetricBlock(label: "Sets logged",
                                              value: "\(doneSets.count)/\(plan.prescribedSetCount)",
                                              tint: HCDesign.electric)
                                HCMetricBlock(label: "Volume",
                                              value: volume.formatted(.number.precision(.fractionLength(0))) + " lb")
                                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                    HCMetricBlock(label: "Elapsed",
                                                  value: hcDuration(coach.phoneSessionStartedAt.map {
                                                      timeline.date.timeIntervalSince($0)
                                                  } ?? 0))
                                }
                            }
                            if coach.phoneSessionStartedAt == nil {
                                HCFilledButton(title: "START WORKOUT", icon: "play.fill") {
                                    coach.startPhoneWorkout()
                                }
                            } else {
                                HCOutlineButton(title: "Finish workout", icon: "stop.fill") {
                                    coach.finishPhoneWorkout()
                                }
                            }
                            HStack(spacing: 10) {
                                HCOutlineButton(title: "Edit program", icon: "slider.horizontal.3") {
                                    showEditor = true
                                }
                                HCOutlineButton(title: "Send to watch", icon: "applewatch") {
                                    coach.sendToWatch()
                                }
                            }
                        }
                    }
                    HCSectionTitle(title: "Workout lineup", detail: "Tap to train")
                    ForEach(plan.exercises.indices, id: \.self) { index in
                        let exercise = plan.exercises[index]
                        NavigationLink {
                            PremiumExerciseSession(exerciseID: exercise.id)
                        } label: {
                            PremiumExerciseCard(index: index + 1, exercise: exercise,
                                                workoutDate: plan.date,
                                                logged: doneSets.filter { $0.exerciseID == exercise.id },
                                                aggressive: aggressive)
                        }
                        .buttonStyle(.plain)
                    }
                    HCOutlineButton(title: "Add or rearrange exercises", icon: "plus") {
                        showEditor = true
                    }
                } else {
                    HCCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.largeTitle).foregroundStyle(HCDesign.electric)
                            Text("No strength session planned")
                                .font(HCDesign.display(23))
                            Text("Build one for this date or pick another training day.")
                                .font(.subheadline).foregroundStyle(HCDesign.secondary)
                            HCFilledButton(title: "CREATE WORKOUT", icon: "plus") {
                                showNew = true
                            }
                        }
                    }
                }
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    coach.refresh(date: date)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(HCDesign.electric)
                }
                .accessibilityLabel("Refresh strength workout")
            }
        }
        .sheet(isPresented: $showEditor) {
            PremiumWorkoutEditor()
                .environmentObject(coach)
        }
        .alert("New training session", isPresented: $showNew) {
            TextField("Workout title", text: $newTitle)
            Button("Create") { coach.newWorkout(date: date, title: newTitle) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct PremiumExerciseCard: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    let index: Int
    let exercise: HCExercise
    let workoutDate: String
    let logged: [HCLoggedSet]
    let aggressive: Bool

    var body: some View {
        let recommendation = coach.suggestion(for: exercise, on: workoutDate, aggressive: aggressive)
        HCCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 11) {
                    Text(String(format: "%02d", index))
                        .font(HCDesign.metric(18))
                        .foregroundStyle(HCDesign.electric)
                        .frame(width: 35, alignment: .leading)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(exercise.name)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(HCDesign.ink)
                        Text("\(exercise.prescribedSets) sets  ·  \(exercise.repDescription) reps  ·  \(exercise.restSeconds)s rest")
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(HCDesign.secondary)
                }
                Rectangle().fill(HCDesign.outline.opacity(0.65)).frame(height: 1)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("COACH LOAD")
                            .font(HCDesign.label(10)).tracking(1)
                            .foregroundStyle(HCDesign.secondary)
                        if let weight = exercise.suggestedWeightLb ?? recommendation.weightLb {
                            Text(weight.formatted() + (recommendation.perDumbbell ? " / DB" : " lb"))
                                .font(HCDesign.metric(21))
                                .foregroundStyle(HCDesign.electric)
                        } else {
                            Text("Set a baseline")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(HCDesign.ink)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        HCAccentTag(title: recommendation.confidence,
                                    color: recommendation.confidence == "High" ?
                                    HCDesign.electric : HCDesign.aqua)
                        Text("\(logged.count) / \(exercise.prescribedSets) completed")
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Workout builder and set controls

private struct PremiumWorkoutEditor: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Environment(\.dismiss) private var dismiss
    @State private var library = false
    @State private var workoutName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Workout name", text: $workoutName)
                        .font(.headline)
                    Button("Save workout name") {
                        guard let p = coach.workout, !workoutName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        save(title: workoutName, list: p.exercises)
                    }
                    .foregroundStyle(HCDesign.electric)
                }
                Section("Press and drag to reorder; swipe left to remove") {
                    if let p = coach.workout {
                        ForEach(p.exercises) { ex in
                            HStack(spacing: 10) {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(HCDesign.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ex.name).font(.subheadline.bold())
                                    Text("\(ex.prescribedSets) × \(ex.repDescription)")
                                        .font(.caption).foregroundStyle(HCDesign.secondary)
                                }
                            }
                            .listRowBackground(HCDesign.card)
                        }
                        .onMove { source, destination in
                            var list = p.exercises
                            list.move(fromOffsets: source, toOffset: destination)
                            save(title: p.title, list: list)
                        }
                        .onDelete { offsets in
                            var list = p.exercises
                            list.remove(atOffsets: offsets)
                            save(title: p.title, list: list)
                        }
                    }
                }
                Section {
                    Button {
                        library = true
                    } label: {
                        Label("Add from exercise library", systemImage: "plus.circle.fill")
                            .foregroundStyle(HCDesign.electric)
                    }
                }
                Section {
                    Text("Individual exercise details provide set-count, rep range, rest duration, movement substitutions and personalized instructions.")
                        .font(.caption).foregroundStyle(HCDesign.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(HCDesign.canvas)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("EDIT WORKOUT")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(HCDesign.electric)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $library) {
            ExerciseLibraryPicker { item in
                guard let p = coach.workout, p.exercises.count < 35 else { return }
                let index = (p.exercises.map(\.exerciseIndex).max() ?? -1) + 1
                guard index <= 40 else { return }
                let prototype = HCExercise(id: UUID().uuidString, name: item.name,
                                           originalName: item.name, exerciseIndex: index,
                                           prescribedSets: 3, repMin: 8, repMax: 12,
                                           suggestedWeightLb: nil, restSeconds: 120)
                let suggested = coach.suggestion(for: prototype, on: p.date)
                var configured = HCExercise(id: prototype.id, name: prototype.name,
                                           originalName: prototype.originalName,
                                           exerciseIndex: index, prescribedSets: 3,
                                           repMin: 8, repMax: 12,
                                           suggestedWeightLb: suggested.weightLb, restSeconds: 120)
                configured.instructions = item.instructions
                save(title: p.title, list: p.exercises + [configured])
            }
        }
        .onAppear { workoutName = coach.workout?.title ?? "" }
    }

    private func save(title: String, list: [HCExercise]) {
        guard let p = coach.workout else { return }
        coach.saveEditedWorkout(HCWorkout(id: p.id, date: p.date, sessionKey: p.sessionKey,
                                         title: title, exercises: list, isPreview: false))
    }
}

private struct PremiumExerciseSession: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @AppStorage("hcAggressiveProgression") private var aggressive = true
    let exerciseID: String
    @State private var hasWeight = false
    @State private var weight = 0.0
    @State private var reps = 8
    @State private var rir = 2

    private var ex: HCExercise? { coach.workout?.exercises.first { $0.id == exerciseID } }
    private var completed: [HCLoggedSet] {
        guard let p = coach.workout else { return [] }
        return coach.loggedSets.filter { $0.workoutID == p.id && $0.exerciseID == exerciseID }
            .sorted { $0.index < $1.index }
    }
    private var active: Bool { coach.phoneSetExerciseID == exerciseID && coach.phoneSetStartedAt != nil }

    var body: some View {
        ScrollView {
            if let ex, let p = coach.workout {
                let suggested = coach.suggestion(for: ex, on: p.date, aggressive: aggressive)
                VStack(alignment: .leading, spacing: 18) {
                    PremiumHeader(eyebrow: "STRENGTH / EXERCISE",
                                  title: ex.name,
                                  subtitle: "\(ex.prescribedSets) sets · \(ex.repDescription) reps · \(ex.restSeconds)s rest")
                    HCCard(accent: HCDesign.aqua) {
                        VStack(alignment: .leading, spacing: 11) {
                            HCAccentTag(title: "INTELLIGENT TARGET", color: HCDesign.aqua)
                            HStack(alignment: .firstTextBaseline) {
                                Text((ex.suggestedWeightLb ?? suggested.weightLb)?.formatted() ?? "—")
                                    .font(HCDesign.display(42))
                                    .foregroundStyle(HCDesign.electric)
                                Text(suggested.perDumbbell ? "lb per dumbbell" : "lb")
                                    .font(.system(size: 13))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            Text(suggested.explanation)
                                .font(.system(size: 12))
                                .foregroundStyle(HCDesign.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                HCAccentTag(title: suggested.confidence)
                                Spacer()
                                Text("\(completed.count) / \(ex.prescribedSets) SETS")
                                    .font(HCDesign.label(10))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                    }
                    HCSectionTitle(title: "Set controls", detail: "Tap + or –")
                    HCCard {
                        VStack(spacing: 16) {
                            Toggle(isOn: $hasWeight) {
                                Text("RECORD WEIGHT")
                                    .font(HCDesign.label(11))
                                    .tracking(1)
                            }
                            .tint(HCDesign.electric)
                            if hasWeight {
                                HCNumberControl(label: suggested.perDumbbell ? "LB / DUMBBELL" : "WEIGHT · LB",
                                                value: weight.formatted(),
                                                decrement: { weight = max(0, weight - 5) },
                                                increment: { weight = min(1500, weight + 5) })
                            }
                            HCNumberControl(label: "REPETITIONS", value: "\(reps)",
                                            decrement: { reps = max(1, reps - 1) },
                                            increment: { reps = min(60, reps + 1) })
                            HCNumberControl(label: "REPS IN RESERVE", value: "\(rir)",
                                            decrement: { rir = max(0, rir - 1) },
                                            increment: { rir = min(6, rir + 1) })
                        }
                    }
                    HCCard(accent: active ? HCDesign.electric : nil) {
                        VStack(alignment: .leading, spacing: 12) {
                            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                if active, let started = coach.phoneSetStartedAt {
                                    HCMetricBlock(label: "Set elapsed",
                                                  value: hcDuration(timeline.date.timeIntervalSince(started)),
                                                  tint: HCDesign.electric)
                                } else if let rest = coach.phoneRestEndsAt, rest > timeline.date {
                                    HCMetricBlock(label: "Recovery countdown",
                                                  value: hcDuration(rest.timeIntervalSince(timeline.date)),
                                                  tint: HCDesign.aqua)
                                }
                            }
                            if coach.phoneSessionStartedAt == nil {
                                HCFilledButton(title: "START WORKOUT TIMER", icon: "play.fill") {
                                    coach.startPhoneWorkout()
                                }
                            } else if active {
                                HCFilledButton(title: "STOP & SAVE SET", icon: "checkmark.circle.fill") {
                                    coach.logFromPhone(exercise: ex, weightLb: hasWeight ? weight : nil,
                                                       reps: reps, rir: Double(rir))
                                }
                                HCOutlineButton(title: "Cancel active set", icon: "xmark") {
                                    coach.cancelPhoneSet()
                                }
                            } else if coach.phoneSetStartedAt == nil {
                                HCFilledButton(title: "START SET \(completed.count + 1)", icon: "play.fill") {
                                    coach.startPhoneSet(exercise: ex)
                                }
                            } else {
                                Text("Another set is active. Finish it before starting this movement.")
                                    .font(.caption).foregroundStyle(HCDesign.secondary)
                            }
                            if coach.phoneRestEndsAt != nil {
                                HCOutlineButton(title: "Skip rest countdown", icon: "forward.fill") {
                                    coach.skipPhoneRest()
                                }
                            }
                            HCOutlineButton(title: "Log without timing", icon: "plus.circle") {
                                coach.logFromPhone(exercise: ex, weightLb: hasWeight ? weight : nil,
                                                   reps: reps, rir: Double(rir))
                            }
                        }
                    }
                    HCSectionTitle(title: "Set history", detail: "Recorded this session")
                    ForEach(completed) { set in
                        HCCard {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HCDesign.electric)
                                Text("SET \(set.index)")
                                    .font(HCDesign.label(12))
                                Spacer()
                                Text("\(set.weightLb?.formatted() ?? "—") lb × \(set.reps)")
                                    .font(HCDesign.metric(17))
                            }
                        }
                    }
                    NavigationLink {
                        StrengthExerciseDetails(exerciseID: exerciseID)
                    } label: {
                        HStack {
                            Label("Edit targets, swap exercise or correct sets", systemImage: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(HCDesign.aqua)
                        .padding(12)
                    }
                    if let instructions = ex.instructions ??
                        HCExerciseLibrary.all.first(where: {
                            HCProgramCatalog.normalized($0.name) == HCProgramCatalog.normalized(ex.name)
                        })?.instructions {
                        HCCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HCSectionTitle(title: "Movement cues")
                                Text(instructions)
                                    .font(.subheadline)
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let ex {
                reps = ex.repMin
                if let target = ex.suggestedWeightLb ??
                    coach.workout.map({ coach.suggestion(for: ex, on: $0.date, aggressive: aggressive).weightLb }) ?? nil {
                    weight = target
                    hasWeight = true
                }
            }
        }
    }
}

// MARK: - Run

private struct PremiumRunPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Binding var date: Date

    private var actual: HCProgressRun? {
        coach.runHistory.first { $0.date == HCPlanBuilder.dateString(date) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                PremiumHeader(eyebrow: "ENDURANCE / RUN",
                              title: "Find your pace.",
                              subtitle: "The plan, the splits, and the real result.")
                PremiumDatePicker(date: $date)
                if !coach.signedIn { PremiumLogin() }
                HCCard(accent: HCDesign.aqua) {
                    VStack(alignment: .leading, spacing: 17) {
                        HCAccentTag(title: "TODAY'S RUN", color: HCDesign.aqua)
                        Text(coach.runPlan?.title ?? "Nothing scheduled")
                            .font(HCDesign.display(26))
                        Text(coach.runPlan?.notes.isEmpty == false ?
                             (coach.runPlan?.notes ?? "") :
                             "Check the calendar for a planned run or review previous sessions.")
                            .font(.subheadline)
                            .foregroundStyle(HCDesign.secondary)
                        HStack {
                            HCMetricBlock(label: "Distance target",
                                          value: coach.runPlan?.targetDistanceMiles.map {
                                              String(format: "%.1f", $0) + " mi"
                                          } ?? "—", tint: HCDesign.aqua)
                            HCMetricBlock(label: "Session",
                                          value: coach.runPlan?.isCompleted == true ? "DONE" : "READY")
                        }
                        HCFilledButton(title: "SEND RUN TO WATCH", icon: "applewatch",
                                       tint: HCDesign.aqua, disabled: coach.runPlan == nil) {
                            coach.sendToWatch()
                        }
                    }
                }
                if let actual {
                    HCSectionTitle(title: "Last recorded result", detail: actual.source)
                    HCCard {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                HCMetricBlock(label: "Distance",
                                              value: actual.distanceMeters.map {
                                                  String(format: "%.2f", $0 / 1609.344) + " mi"
                                              } ?? "—")
                                HCMetricBlock(label: "Elapsed",
                                              value: actual.durationSeconds.map(hcDuration) ?? "—",
                                              tint: HCDesign.electric)
                            }
                            if let meters = actual.distanceMeters, let seconds = actual.durationSeconds,
                               meters > 0 {
                                let perMile = seconds * 1609.344 / meters
                                Text("AVG PACE · \(hcDuration(perMile)) /mi")
                                    .font(HCDesign.label(12))
                                    .foregroundStyle(HCDesign.aqua)
                            }
                            if !actual.splits.isEmpty {
                                HCSectionTitle(title: "Measured laps")
                                ForEach(actual.splits) { split in
                                    HStack {
                                        Text("SPLIT \(split.index)")
                                            .font(HCDesign.label(11))
                                            .foregroundStyle(HCDesign.secondary)
                                        Spacer()
                                        Text(hcDuration(split.elapsedSeconds))
                                            .font(HCDesign.metric(17))
                                    }
                                    .padding(.vertical, 5)
                                }
                            }
                        }
                    }
                }
                HCSectionTitle(title: "Previous runs", detail: "Recorded only")
                ForEach(Array(coach.runHistory.prefix(15))) { run in
                    HCCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(run.date).font(HCDesign.label(11)).foregroundStyle(HCDesign.aqua)
                                Text(run.title).font(.system(size: 15, weight: .bold))
                                Text(run.source).font(.caption2).foregroundStyle(HCDesign.secondary)
                            }
                            Spacer()
                            Text(run.distanceMeters.map { String(format: "%.2f", $0 / 1609.344) } ?? "—")
                                .font(HCDesign.metric(20))
                            Text("mi").font(.caption).foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                if coach.runHistory.isEmpty {
                    HCCard {
                        Text("Completed runs will appear here when they sync from your watch or existing account.")
                            .font(.subheadline).foregroundStyle(HCDesign.secondary)
                    }
                }
                Spacer(minLength: 26)
            }
            .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Analytics

private struct HCPlotMark: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private struct PremiumProgressPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @State private var selectedExercise = ""

    private var names: [String] { Array(Set(coach.performanceHistory.map(\.exercise))).sorted() }
    private var current: String { selectedExercise.isEmpty ? (names.first ?? "") : selectedExercise }
    private var strengthPoints: [HCPlotMark] {
        coach.performanceHistory.filter { $0.exercise == current }
            .compactMap { row in
                HCPlanBuilder.startOfDate(row.date).map {
                    HCPlotMark(date: $0, value: row.weightLb)
                }
            }.sorted { $0.date < $1.date }
    }
    private var runPoints: [HCPlotMark] {
        coach.runHistory.compactMap { row in
            guard let distance = row.distanceMeters, let date = HCPlanBuilder.startOfDate(row.date)
            else { return nil }
            return HCPlotMark(date: date, value: distance / 1609.344)
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                PremiumHeader(eyebrow: "PERFORMANCE / OVERVIEW",
                              title: "Built over time.",
                              subtitle: "Actual logged work. No invented recovery scores.")
                HStack(spacing: 11) {
                    HCCard {
                        HCMetricBlock(label: "Strength sets",
                                      value: "\(coach.performanceHistory.count)",
                                      tint: HCDesign.electric)
                    }
                    HCCard {
                        HCMetricBlock(label: "Runs", value: "\(coach.runHistory.count)",
                                      tint: HCDesign.aqua)
                    }
                }
                HCCard {
                    HCMetricBlock(label: "Total logged run distance",
                                  value: String(format: "%.1f mi",
                                    coach.runHistory.compactMap(\.distanceMeters).reduce(0,+) / 1609.344),
                                  tint: HCDesign.electric)
                }
                HCSectionTitle(title: "Exercise progression", detail: "Recorded weight")
                HCCard {
                    VStack(alignment: .leading, spacing: 16) {
                        if names.isEmpty {
                            Text("Your actual logged strength history will appear after sync.")
                                .font(.subheadline).foregroundStyle(HCDesign.secondary)
                        } else {
                            Picker("Exercise", selection: $selectedExercise) {
                                Text("Select movement").tag("")
                                ForEach(names, id: \.self) { Text($0).tag($0) }
                            }
                            .tint(HCDesign.aqua)
                            if !strengthPoints.isEmpty {
                                Chart(strengthPoints) { point in
                                    LineMark(x: .value("Date", point.date),
                                             y: .value("Weight", point.value))
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(HCDesign.electric)
                                    PointMark(x: .value("Date", point.date),
                                              y: .value("Weight", point.value))
                                        .foregroundStyle(HCDesign.electric)
                                }
                                .chartYAxisLabel("lb")
                                .frame(height: 205)
                            }
                        }
                        Text("Equipment-specific loads are kept separate. Dumbbell weights are per implement.")
                            .font(.caption2).foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Running volume")
                HCCard {
                    if runPoints.isEmpty {
                        Text("No measured running distances yet.")
                            .foregroundStyle(HCDesign.secondary)
                    } else {
                        Chart(runPoints) { p in
                            BarMark(x: .value("Date", p.date, unit: .day),
                                    y: .value("Miles", p.value))
                                .foregroundStyle(HCDesign.aqua.gradient)
                                .cornerRadius(4)
                        }
                        .frame(height: 210)
                    }
                }
                Spacer(minLength: 30)
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Recovery: no invented WHOOP readiness

private struct PremiumRecoveryPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @ObservedObject var appleHealth: HCAppleHealthReader

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                PremiumHeader(eyebrow: "RECOVERY / SIGNALS",
                              title: "Know your baseline.",
                              subtitle: "Source-labeled recovery. No fictional metrics.")
                HCCard(accent: HCDesign.aqua) {
                    VStack(alignment: .leading, spacing: 14) {
                        HCAccentTag(title: "APPLE HEALTH", color: HCDesign.aqua)
                        Text("Apple Watch + WHOOP")
                            .font(HCDesign.display(23))
                        Text("Measurements appear only after permission. WHOOP data shows here only if it has been shared to Apple Health.")
                            .font(.subheadline).foregroundStyle(HCDesign.secondary)
                        HCFilledButton(title: "READ HEALTH MEASUREMENTS",
                                       icon: "heart.text.square", tint: HCDesign.aqua) {
                            appleHealth.connect()
                        }
                        Text(appleHealth.status)
                            .font(.caption2).foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Latest device readings")
                ForEach(appleHealth.metrics) { metric in
                    HCCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(metric.name.uppercased())
                                    .font(HCDesign.label()).tracking(1.2)
                                    .foregroundStyle(HCDesign.secondary)
                                Text(metric.source + " · " + metric.date)
                                    .font(.caption2).foregroundStyle(HCDesign.secondary)
                            }
                            Spacer()
                            Text(metric.value)
                                .font(HCDesign.metric(25))
                                .foregroundStyle(HCDesign.electric)
                        }
                    }
                }
                HCSectionTitle(title: "Existing Tredict recovery")
                if let result = coach.recoveryHistory.first {
                    HCCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(result.date + " · " + result.source)
                                .font(.caption)
                                .foregroundStyle(HCDesign.secondary)
                            HStack {
                                HCMetricBlock(label: "Sleep",
                                              value: result.sleepSeconds.map(hcDuration) ?? "—")
                                HCMetricBlock(label: "HRV RMSSD",
                                              value: result.hrvMS.map { "\($0.formatted()) ms" } ?? "—",
                                              tint: HCDesign.aqua)
                            }
                            HStack {
                                HCMetricBlock(label: "Daily low HR",
                                              value: result.dailyLowHR.map { "\($0.formatted())" } ?? "—")
                                HCMetricBlock(label: "14-day HRV baseline",
                                              value: result.hrvBaselineMS.map { "\($0.formatted())" } ?? "—")
                            }
                        }
                    }
                } else {
                    HCCard {
                        Text("Tredict history will appear when connected and synced.")
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                HCCard {
                    Text("Apple Health HRV (SDNN), Tredict HRV (RMSSD), and WHOOP Recovery use different definitions. We show labels and sources rather than combining them into a misleading score.")
                        .font(.caption)
                        .foregroundStyle(HCDesign.secondary)
                }
                Spacer(minLength: 30)
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
    }
}

// MARK: - Coaching, export and settings

private struct PremiumCoachPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @AppStorage("hcAggressiveProgression") private var aggressive = true
    @AppStorage("hcCoachingNotes") private var notes = ""
    @AppStorage("hcIncludeRecoveryExport") private var includeRecovery = false

    private var export: String {
        var lines = ["# Health Coach Training Export",
                     "Aggressive progression: \(aggressive)",
                     "## Coach notes", notes, "## Strength"]
        for s in coach.performanceHistory.sorted(by: { $0.date > $1.date }).prefix(250) {
            lines.append("\(s.date): \(s.exercise) · \(s.weightLb.formatted()) lb × \(s.reps) · RIR \(s.rir?.formatted() ?? "—")")
        }
        lines.append("## Running")
        for run in coach.runHistory.prefix(100) {
            let distance = run.distanceMeters.map { String(format: "%.2f mi", $0 / 1609.344) } ?? "—"
            lines.append("\(run.date): \(run.title) · \(distance) · \(run.source)")
        }
        if includeRecovery {
            lines.append("## Recovery")
            for item in coach.recoveryHistory.prefix(90) {
                lines.append("\(item.date): sleep \(item.sleepSeconds.map(hcDuration) ?? "—"), HRV RMSSD \(item.hrvMS?.formatted() ?? "—") ms, source: \(item.source)")
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                PremiumHeader(eyebrow: "COACH / CONTROL CENTER",
                              title: "Your game plan.",
                              subtitle: "Preferences, feedback, exports and connections.")
                HCCard(accent: HCDesign.electric) {
                    VStack(alignment: .leading, spacing: 11) {
                        HCAccentTag(title: "TRAINING INTELLIGENCE")
                        Toggle(isOn: $aggressive) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Smart aggressive progression").font(.headline)
                                Text("Add reps first; increase load when earned.")
                                    .font(.caption)
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                        .tint(HCDesign.electric)
                        Text("Movement changes use conservative estimates, confidence labels, and your subsequent actual performance.")
                            .font(.caption2).foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Your coaching notes")
                HCCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Soreness, schedule changes, substitutions, goals...")
                            .font(.caption).foregroundStyle(HCDesign.secondary)
                        TextEditor(text: $notes)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .padding(6)
                            .background(HCDesign.raised, in: RoundedRectangle(cornerRadius: 13))
                    }
                }
                HCSectionTitle(title: "AI export & sharing")
                HCCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Include recovery measurements", isOn: $includeRecovery)
                            .tint(HCDesign.electric)
                        ShareLink(item: export) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("EXPORT TRAINING FOR AI")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(HCDesign.canvas)
                            .padding(16)
                            .background(HCDesign.electric, in: RoundedRectangle(cornerRadius: 14))
                        }
                        Text("Only you decide whether and where to share this export.")
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Connections")
                HCCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HCSyncStatus(pending: coach.cloudPendingCount,
                                     saving: coach.savingPlan, connected: coach.signedIn)
                        Text(coach.status)
                            .font(.caption).foregroundStyle(HCDesign.secondary)
                        HCOutlineButton(title: "Retry all uploads", icon: "arrow.clockwise") {
                            coach.retryPendingWorkout()
                            coach.retryPendingCloudSets()
                        }
                        HCOutlineButton(title: "Send current plan to watch", icon: "applewatch") {
                            coach.sendToWatch()
                        }
                        if !coach.signedIn {
                            PremiumLogin()
                        } else {
                            HCOutlineButton(title: "Sign out", icon: "rectangle.portrait.and.arrow.right") {
                                coach.logout()
                            }
                        }
                    }
                }
                Spacer(minLength: 30)
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
    }
}
