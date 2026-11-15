import SwiftUI
import Charts
import MapKit

// The bottom bar is organized by purpose; individual sports live inside Training.
// Adding cycling, mobility or swimming later does not require another bottom tab.
private enum IMUNTrainingActivity: String, CaseIterable, Identifiable {
    case run
    case weightlifting

    var id: String { rawValue }
    var title: String {
        switch self {
        case .run: return "Run"
        case .weightlifting: return "Weightlifting"
        }
    }
    var symbol: String {
        switch self {
        case .run: return "figure.run"
        case .weightlifting: return "dumbbell.fill"
        }
    }
}

// MARK: - Health Coach 2.0 navigation

struct PremiumHomeView: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @StateObject private var appleHealth = HCAppleHealthReader()
    @StateObject private var runImporter = HCRunHealthImporter()
    @StateObject private var tredictImporter = HCTredictImporter()
    @AppStorage("hcAccentStyle") private var accentStyle = "crimson"
    @Environment(\.scenePhase) private var scenePhase
    private let scheduleRefresh = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            NavigationStack { PremiumTrainingPage() }
                .tabItem { Label("Training", systemImage: "figure.run.circle.fill") }
            NavigationStack { PremiumProgressPage() }
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
            NavigationStack { PremiumRecoveryPage(appleHealth: appleHealth) }
                .tabItem { Label("Recovery", systemImage: "waveform.path.ecg") }
            NavigationStack { PremiumCoachPage() }
                .tabItem { Label("Coach", systemImage: "bubble.left.and.text.bubble.right") }
        }
        .tint(HCDesign.electric)
        .preferredColorScheme(.dark)
        .environmentObject(runImporter)
        .environmentObject(tredictImporter)
        .onReceive(tredictImporter.$snapshot) { snapshot in
            if snapshot.lastSync != nil {
                coach.updateTredictSnapshot(snapshot)
            }
        }
        .onReceive(runImporter.$runs) { imported in
            coach.updateHealthRuns(imported)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                runImporter.startIfAuthorized()
                if coach.signedIn { coach.refresh(date: Date()) }
            }
        }
        .onReceive(scheduleRefresh) { _ in
            // Poll the Command Center calendar while the iPhone app is open.
            // watchOS cannot independently invent or reschedule a session.
            if scenePhase == .active && coach.signedIn && !coach.loading {
                coach.refreshTodaySchedule()
            }
        }
        .onChange(of: accentStyle) { _, _ in
            configureTabAppearance()
            coach.sendToWatch()
        }
        .onAppear {
            if coach.signedIn && coach.workout == nil { coach.refresh(date: Date()) }
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


// One Training destination. The picker controls the sport, not the daily plan:
// each activity still reads its date-matched workout from the iPhone calendar.
private struct PremiumTrainingPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @AppStorage("hcTrainingActivity") private var chosenActivity = "weightlifting"

    private var selected: IMUNTrainingActivity {
        IMUNTrainingActivity(rawValue: chosenActivity) ?? .weightlifting
    }

    private var plannedTitle: String {
        let today = HCPlanBuilder.dateString(Date())
        switch selected {
        case .run:
            return coach.runPlan?.date == today
                ? (coach.runPlan?.title ?? "No run planned")
                : "No run planned today"
        case .weightlifting:
            return coach.workout?.date == today
                ? (coach.workout?.title ?? "No lift planned")
                : "No lift planned today"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("IMUN / YOUR SESSIONS")
                            .font(HCDesign.label(10))
                            .tracking(1.8)
                            .foregroundStyle(HCDesign.aqua)
                        Text("Training")
                            .font(HCDesign.display(32))
                            .foregroundStyle(HCDesign.ink)
                    }
                    Spacer()
                    Text(Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(HCDesign.label(11))
                        .foregroundStyle(HCDesign.secondary)
                }

                HStack(spacing: 9) {
                    ForEach(IMUNTrainingActivity.allCases) { activity in
                        let active = selected == activity
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                chosenActivity = activity.rawValue
                            }
                        } label: {
                            Label(activity.title, systemImage: activity.symbol)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .foregroundStyle(active ? HCDesign.onAccent : HCDesign.secondary)
                                .background(active ? HCDesign.electric : HCDesign.raised,
                                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .strokeBorder(active ? HCDesign.electric : HCDesign.outline,
                                                      lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(active ? [.isSelected] : [])
                    }
                }
                .accessibilityLabel("Training activity")

                HStack(spacing: 9) {
                    Image(systemName: "calendar")
                        .foregroundStyle(HCDesign.aqua)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("TODAY'S PLAN")
                            .font(HCDesign.label(9))
                            .tracking(1.2)
                            .foregroundStyle(HCDesign.secondary)
                        Text(plannedTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(HCDesign.ink)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(HCDesign.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(HCDesign.card, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 14)

            Rectangle()
                .fill(HCDesign.outline.opacity(0.65))
                .frame(height: 1)

            Group {
                switch selected {
                case .run: PremiumRunPage()
                case .weightlifting: PremiumStrengthPage()
                }
            }
        }
        .hcPage()
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
                    .tracking(1.1)
                    .foregroundStyle(HCDesign.aqua)
                Spacer()
                if let badge { HCAccentTag(title: badge) }
            }
            Text(title)
                .font(HCDesign.display(32))
                .tracking(-0.5)
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
    private var date: Date { Date() }
    @State private var movingSession: HCPlannedSession?
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
                HCSectionTitle(title: "Weightlifting", detail: aggressive ? "Coached session" : "Today's plan")
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
                            if let entry = coach.plannedSessions.first(where: {
                                $0.date == HCPlanBuilder.dateString(date) &&
                                     ($0.kind == "lift" || $0.kind == "lift-template")
                            }) {
                                HCOutlineButton(title: "Move this workout", icon: "calendar.badge.clock") {
                                    movingSession = entry
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
                            Text("Create a session for today, or move an upcoming one here from Progress.")
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
        .sheet(item: $movingSession) { entry in
            IMUNMoveWorkoutSheet(entry: entry)
                .environmentObject(coach)
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
                let target = ex.suggestedWeightLb ?? coach.workout.flatMap {
                    coach.suggestion(for: ex, on: $0.date, aggressive: aggressive).weightLb
                }
                if let target {
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
    @EnvironmentObject private var importer: HCRunHealthImporter
    private var date: Date { Date() }
    @State private var movingSession: HCPlannedSession?

    private var actual: HCProgressRun? {
        coach.runHistory.first { $0.date == HCPlanBuilder.dateString(date) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                HCSectionTitle(title: "Running", detail: "Today's plan")
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
                        if let entry = coach.plannedSessions.first(where: {
                            $0.date == HCPlanBuilder.dateString(date) && $0.kind == "run"
                        }) {
                            HCOutlineButton(title: "Move this run", icon: "calendar.badge.clock") {
                                movingSession = entry
                            }
                        }
                    }
                }
                if let actual {
                    HCSectionTitle(title: "Completed run", detail: actual.source)
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
                            HStack(spacing: 12) {
                                HCMetricBlock(label: "Average HR",
                                              value: actual.averageBPM.map { "\(Int($0)) bpm" } ?? "—",
                                              tint: HCDesign.aqua)
                                HCMetricBlock(label: "Calories",
                                              value: actual.activeCalories.map { "\(Int($0)) kcal" } ?? "—")
                            }
                            NavigationLink {
                                PremiumRunDetails(run: actual)
                            } label: {
                                HStack {
                                    Text("VIEW ALL RECORDED RUN DATA")
                                        .font(HCDesign.label(11))
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .foregroundStyle(HCDesign.electric)
                                .padding(.vertical, 6)
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
                HCCard(accent: HCDesign.aqua) {
                    VStack(alignment: .leading, spacing: 12) {
                        HCAccentTag(title: "AUTO-IMPORT / APPLE HEALTH", color: HCDesign.aqua)
                        Text(importer.enabled ? "Runs sync automatically" : "Connect completed workouts")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Text("Bring in running workouts from Apple Workout and WHOOP when they appear in Apple Health. Individual metrics depend on what each source shares.")
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                        if importer.enabled {
                            HCOutlineButton(title: importer.refreshing ? "Checking Health…" : "Check new runs",
                                            icon: "arrow.clockwise") { importer.refresh() }
                        } else {
                            HCFilledButton(title: "CONNECT APPLE HEALTH", icon: "heart.fill",
                                           tint: HCDesign.aqua) { importer.connect() }
                        }
                        Text(importer.status).font(.caption2).foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Previous runs", detail: "Recorded only")
                ForEach(Array(coach.runHistory.prefix(15))) { run in
                    NavigationLink {
                        PremiumRunDetails(run: run)
                    } label: {
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
                                Image(systemName: "chevron.right")
                                    .font(.caption2).foregroundStyle(HCDesign.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
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
        .sheet(item: $movingSession) { entry in
            IMUNMoveWorkoutSheet(entry: entry)
                .environmentObject(coach)
        }
    }
}

private struct PremiumRunDetails: View {
    let run: HCProgressRun

    private func number(_ v: Double?, unit: String = "", digits: Int = 0) -> String {
        guard let v else { return "Not shared" }
        return v.formatted(.number.precision(.fractionLength(digits))) + unit
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                PremiumHeader(eyebrow: "RUN / RECORDED", title: run.title,
                              subtitle: run.date + " · " + run.source,
                              badge: run.fromAppleHealth ? "APPLE HEALTH" : "CONNECTED")
                HCCard(accent: HCDesign.aqua) {
                    VStack(spacing: 17) {
                        HStack {
                            HCMetricBlock(label: "Distance", value: run.distanceMeters.map {
                                String(format: "%.2f mi", $0 / 1609.344)
                            } ?? "Not shared", tint: HCDesign.aqua)
                            HCMetricBlock(label: "Elapsed", value: run.durationSeconds.map(hcDuration) ?? "—")
                        }
                        HStack {
                            HCMetricBlock(label: "Average pace", value: {
                                guard let meters = run.distanceMeters, meters > 0,
                                      let seconds = run.durationSeconds else { return "—" }
                                return hcDuration(seconds * 1609.344 / meters) + "/mi"
                            }())
                            HCMetricBlock(label: "Active energy", value: number(run.activeCalories, unit: " kcal"))
                        }
                        HStack {
                            HCMetricBlock(label: "Average heart rate", value: number(run.averageBPM, unit: " bpm"))
                            HCMetricBlock(label: "Maximum heart rate", value: number(run.maxBPM, unit: " bpm"))
                        }
                        HStack {
                            HCMetricBlock(label: "Average run power", value: number(run.averagePowerWatts, unit: " W"))
                            HCMetricBlock(label: "Cadence", value: number(run.averageCadenceSPM, unit: " spm"))
                        }
                        HCMetricBlock(label: "Elevation gained", value: number(run.elevationGainMeters, unit: " m"))
                    }
                }
                if !run.heartRateTrace.isEmpty {
                    HCSectionTitle(title: "Heart rate over time", detail: run.source)
                    HCCard {
                        Chart(run.heartRateTrace) { item in
                            LineMark(x: .value("Time", item.at),
                                     y: .value("Heart rate", item.bpm))
                                .foregroundStyle(HCDesign.aqua)
                                .interpolationMethod(.linear)
                        }
                        .chartYAxisLabel("bpm")
                        .frame(height: 205)
                    }
                }
                if !run.routePoints.isEmpty {
                    HCSectionTitle(title: "Recorded GPS route", detail: run.source)
                    HCCard {
                        let points = run.routePoints.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        }
                        let latitudes = run.routePoints.map(\.latitude)
                        let longitudes = run.routePoints.map(\.longitude)
                        let latMin = latitudes.min() ?? 0
                        let latMax = latitudes.max() ?? 0
                        let lonMin = longitudes.min() ?? 0
                        let lonMax = longitudes.max() ?? 0
                        let center = CLLocationCoordinate2D(latitude: (latMin + latMax) / 2,
                                                             longitude: (lonMin + lonMax) / 2)
                        let span = MKCoordinateSpan(latitudeDelta: max(0.007, (latMax - latMin) * 1.5),
                                                    longitudeDelta: max(0.007, (lonMax - lonMin) * 1.5))
                        Map(initialPosition: .region(MKCoordinateRegion(center: center, span: span))) {
                            MapPolyline(coordinates: points)
                                .stroke(HCDesign.aqua, lineWidth: 4)
                        }
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("GPS locations remain stored on this iPhone.")
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Recorded lap events", detail: "\(run.splits.count)")
                if run.splits.isEmpty {
                    HCCard {
                        Text("This recorder did not share lap splits. Distance and total elapsed time may still be available.")
                            .font(.subheadline).foregroundStyle(HCDesign.secondary)
                    }
                } else {
                    ForEach(run.splits) { lap in
                        HCCard {
                            HStack {
                                Text("LAP \(lap.index)").font(HCDesign.label(12))
                                Spacer()
                                Text(hcDuration(lap.elapsedSeconds)).font(HCDesign.metric(19))
                                if let meters = lap.distanceMeters {
                                    Text(String(format: "%.2f mi", meters / 1609.344))
                                        .font(.caption).foregroundStyle(HCDesign.secondary)
                                }
                            }
                        }
                    }
                }
                HCCard {
                    VStack(alignment: .leading, spacing: 7) {
                        HCSectionTitle(title: "Provenance")
                        Text("Recorded by: \(run.source)")
                            .font(.system(size: 13, weight: .medium))
                        if let bundleID = run.sourceBundleID {
                            Text(bundleID).font(.caption2).foregroundStyle(HCDesign.secondary)
                        }
                        Text("Only data actually shared by the originating app appears here. Missing values and lap distances are not fabricated.")
                            .font(.caption).foregroundStyle(HCDesign.secondary)
                    }
                }
            }
            .padding(18)
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

/// Date editing lives here, not on the daily workout dashboards.
private struct IMUNMoveWorkoutSheet: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Environment(\.dismiss) private var dismiss
    let entry: HCPlannedSession
    @State private var destination: Date

    init(entry: HCPlannedSession) {
        self.entry = entry
        _destination = State(initialValue: HCPlanBuilder.startOfDate(entry.date) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    Text(entry.title).font(.headline)
                    LabeledContent("Type", value: entry.kind == "lift-template" ?
                                   "Strength rotation" : entry.kind.capitalized)
                    LabeledContent("Current date", value: entry.date)
                }
                Section("Reschedule") {
                    DatePicker("Move to", selection: $destination,
                               displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(HCDesign.electric)
                    Text("Moving a workout updates your Command Center calendar. Previously recorded sets and completed runs stay on their original dates.")
                        .font(.caption)
                        .foregroundStyle(HCDesign.secondary)
                }
                Section {
                    Button {
                        coach.moveWorkout(entry, to: destination)
                        dismiss()
                    } label: {
                        Label("Save new workout day", systemImage: "checkmark")
                            .font(.headline)
                            .foregroundStyle(HCDesign.electric)
                    }
                    .disabled(coach.movingWorkoutID != nil ||
                              HCPlanBuilder.dateString(destination) == entry.date)
                }
            }
            .scrollContentBackground(.hidden)
            .background(HCDesign.canvas)
            .navigationTitle("Move workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct IMUNSetHistoryPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge

    var body: some View {
        List {
            Section {
                Text("Saved working sets from your earlier Health Coach sessions and IMUN Watch recordings. Loads are shown in pounds.")
                    .font(.caption)
                    .foregroundStyle(HCDesign.secondary)
            }
            ForEach(Array(coach.performanceHistory
                .sorted { $0.date == $1.date ? $0.exercise < $1.exercise : $0.date > $1.date }
                .prefix(350).enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.date)
                            .font(HCDesign.label(11))
                            .foregroundStyle(HCDesign.electric)
                        Spacer()
                        Text(row.source)
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                    Text(row.exercise)
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(row.weightLb.formatted()) lb × \(row.reps) reps" +
                         (row.rir.map { "  ·  RIR \($0.formatted())" } ?? ""))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HCDesign.secondary)
                }
                .listRowBackground(HCDesign.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(HCDesign.canvas)
        .navigationTitle("Strength history")
    }
}

private struct IMUNActivityDetails: View {
    let activity: HCTrainingActivity

    private var measurements: [(String, String)] {
        var rows: [(String, String)] = []
        if let seconds = activity.durationSeconds { rows.append(("Moving time", hcDuration(seconds))) }
        if let seconds = activity.totalDurationSeconds { rows.append(("Total elapsed", hcDuration(seconds))) }
        if let meters = activity.distanceMeters { rows.append(("Distance", String(format: "%.2f miles", meters / 1609.344))) }
        if let seconds = activity.paceSecondsPerKm { rows.append(("Pace", hcDuration(seconds * 1.609344) + " /mi")) }
        if let avg = activity.averageBPM { rows.append(("Average heart rate", "\(Int(avg)) bpm")) }
        if let max = activity.maxBPM { rows.append(("Maximum heart rate", "\(Int(max)) bpm")) }
        if let kcal = activity.calories { rows.append(("Calories", "\(Int(kcal)) kcal")) }
        if let watts = activity.powerWatts { rows.append(("Average power", "\(Int(watts)) W")) }
        if let cadence = activity.cadenceSPM { rows.append(("Cadence", "\(Int(cadence)) spm")) }
        if let ascent = activity.ascentMeters { rows.append(("Elevation gained", "\(Int(ascent)) m")) }
        if let sets = activity.strengthSetCount { rows.append(("Recorded strength sets", "\(sets)")) }
        if let reps = activity.strengthRepetitions { rows.append(("Total repetitions", "\(reps)")) }
        if let volume = activity.tonnageKilograms {
            rows.append(("Tonnage", String(format: "%.1f kg", volume)))
        }
        if let load = activity.maxSetWeightKilograms {
            rows.append(("Highest set load", String(format: "%.1f kg", load)))
        }
        if let seconds = activity.activeSetSeconds { rows.append(("Time lifting", hcDuration(seconds))) }
        if let seconds = activity.restSeconds { rows.append(("Time resting", hcDuration(seconds))) }
        if let score = activity.runningEffectiveness {
            rows.append(("Running effectiveness", score.formatted(.number.precision(.fractionLength(2)))))
        }
        if let vo2 = activity.vo2Max {
            rows.append(("Estimated VO₂max", vo2.formatted(.number.precision(.fractionLength(1)))))
        }
        if let effort = activity.perceivedEffort {
            rows.append(("Recorded RPE", effort.formatted(.number.precision(.fractionLength(1)))))
        }
        if let enjoyment = activity.enjoyment {
            rows.append(("Recorded enjoyment", enjoyment.formatted(.number.precision(.fractionLength(1)))))
        }
        return rows
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                PremiumHeader(eyebrow: "IMUN / TRAINING HISTORY",
                              title: activity.title,
                              subtitle: activity.date + " · " + activity.source)
                HCCard {
                    VStack(alignment: .leading, spacing: 13) {
                        ForEach(measurements.indices, id: \.self) { i in
                            HStack(alignment: .firstTextBaseline) {
                                Text(measurements[i].0)
                                    .font(.system(size: 13))
                                    .foregroundStyle(HCDesign.secondary)
                                Spacer(minLength: 7)
                                Text(measurements[i].1)
                                    .font(.system(size: 13, weight: .semibold))
                                    .multilineTextAlignment(.trailing)
                            }
                            if i != measurements.count - 1 { Divider().overlay(HCDesign.outline) }
                        }
                        if measurements.isEmpty {
                            Text("The original service recorded a workout, but did not provide numeric measurements.")
                                .font(.subheadline).foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                HCCard {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ORIGINAL RECORD").font(HCDesign.label(11)).foregroundStyle(HCDesign.electric)
                        Text("Source: " + activity.source)
                            .font(.system(size: 13))
                        if let name = activity.attribution {
                            Text("Device: " + name).font(.system(size: 12)).foregroundStyle(HCDesign.secondary)
                        }
                        Text("All available values retain their original recorded units. Additional raw Tredict fields remain in your local source archive.")
                            .font(.caption).foregroundStyle(HCDesign.secondary)
                    }
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PremiumProgressPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @State private var selectedExercise = ""
    @State private var movingSession: HCPlannedSession?

    private var upcoming: [HCPlannedSession] {
        let today = HCPlanBuilder.dateString(Date())
        return Array(coach.plannedSessions.filter { $0.date >= today }.prefix(45))
    }

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
                PremiumHeader(eyebrow: "IMUN / PROGRESS",
                              title: "Your training",
                              subtitle: "Upcoming workouts and your actual history.")
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
                HCSectionTitle(title: "Upcoming workouts", detail: "Tap to reschedule")
                if upcoming.isEmpty {
                    HCCard {
                        Text("No upcoming sessions in your connected calendar. Add workouts through Command Center.")
                            .font(.subheadline).foregroundStyle(HCDesign.secondary)
                    }
                } else {
                    ForEach(upcoming) { entry in
                        HCCard {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    Text(entry.date)
                                        .font(HCDesign.label(11))
                                        .foregroundStyle(HCDesign.electric)
                                    Spacer()
                                    Text(entry.kind == "lift-template" ? "STRENGTH · ROTATION" : entry.kind.uppercased())
                                        .font(HCDesign.label(10))
                                        .foregroundStyle(HCDesign.secondary)
                                }
                                Text(entry.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(HCDesign.ink)
                                if !entry.notes.isEmpty {
                                    Text(entry.notes)
                                        .font(.caption)
                                        .foregroundStyle(HCDesign.secondary)
                                        .lineLimit(2)
                                }
                                HStack(spacing: 12) {
                                    Button {
                                        movingSession = entry
                                    } label: {
                                        Label("Move day", systemImage: "calendar")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .disabled(coach.movingWorkoutID != nil)
                                    if entry.date != HCPlanBuilder.dateString(Date()) {
                                        Button {
                                            coach.moveWorkout(entry, to: Date())
                                        } label: {
                                            Label("Today", systemImage: "arrow.uturn.backward")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .disabled(coach.movingWorkoutID != nil)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(HCDesign.electric)
                            }
                        }
                    }
                }
                if coach.movingWorkoutID != nil {
                    ProgressView("Saving your schedule…").tint(HCDesign.electric)
                }
                HCSectionTitle(title: "Completed training", detail: "Health Coach + Tredict")
                if coach.trainingActivities.isEmpty {
                    Text("Your previous training sessions will appear after your account finishes syncing.")
                        .foregroundStyle(HCDesign.secondary)
                } else {
                    ForEach(coach.trainingActivities.prefix(35)) { activity in
                        NavigationLink {
                            IMUNActivityDetails(activity: activity)
                        } label: {
                            HCCard {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(activity.date).foregroundStyle(HCDesign.electric)
                                    Spacer()
                                    Text(activity.source).foregroundStyle(HCDesign.secondary)
                                }
                                .font(HCDesign.label(10))
                                Text(activity.title).font(.system(size: 15, weight: .semibold))
                                HStack(spacing: 12) {
                                    if let seconds = activity.durationSeconds {
                                        Label(hcDuration(seconds), systemImage: "clock")
                                    }
                                    if let meters = activity.distanceMeters, meters > 0 {
                                        Label(String(format: "%.2f mi", meters / 1609.344),
                                              systemImage: "figure.run")
                                    }
                                    if let hr = activity.averageBPM {
                                        Label("\(Int(hr)) bpm", systemImage: "heart")
                                    }
                                    if let kcal = activity.calories {
                                        Label("\(Int(kcal)) kcal", systemImage: "flame")
                                    }
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(HCDesign.secondary)
                                .lineLimit(1)
                            }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                HCSectionTitle(title: "Past working sets", detail: "\(coach.performanceHistory.count) records")
                NavigationLink {
                    IMUNSetHistoryPage()
                } label: {
                    HCCard {
                        HStack {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .foregroundStyle(HCDesign.electric)
                            Text("View every logged weight, rep and RIR")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
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
        .sheet(item: $movingSession) { entry in
            IMUNMoveWorkoutSheet(entry: entry)
                .environmentObject(coach)
        }
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
                HCSectionTitle(title: "Tredict / Garmin recovery history",
                               detail: "\(coach.recoveryHistory.count) days")
                ForEach(coach.recoveryHistory, id: \.date) { result in
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
                }
                if coach.recoveryHistory.isEmpty {
                    HCCard {
                        Text("Tredict recovery will appear when the connected service has synced.")
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

// The Coach tab is a briefing and navigation hub; preferences live one tap deeper.
private struct PremiumCoachPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge

    private var today: String { HCPlanBuilder.dateString(Date()) }
    private var lift: HCWorkout? {
        guard let plan = coach.workout, plan.date == today else { return nil }
        return plan
    }
    private var run: HCRunPlan? {
        guard let plan = coach.runPlan, plan.date == today else { return nil }
        return plan
    }
    private var completedSets: Int {
        guard let lift else { return 0 }
        return coach.loggedSets.filter { $0.workoutID == lift.id }.count
    }
    private var plannedSets: Int { lift?.prescribedSetCount ?? 0 }
    private var completion: Double {
        plannedSets > 0 ? min(1, Double(completedSets) / Double(plannedSets)) : 0
    }

    private var coachBriefing: String {
        if !coach.signedIn {
            return "Connect your account to see the training calendar and the sessions you have planned."
        }
        if coach.loading {
            return "Checking your connected training calendar. Your latest schedule will appear here."
        }
        switch (lift != nil, run != nil) {
        case (true, true):
            return "You have both weightlifting and running scheduled today. Review each session in Training and plan enough time between efforts."
        case (true, false):
            return "Today's weightlifting session is ready. Follow your planned sets and record your results for a clearer progression history."
        case (false, true):
            return "Your run is scheduled today. Check the session details in Training before starting on the Watch."
        case (false, false):
            return "No sessions are scheduled for today. Use Training to create a lift or review your connected calendar."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                PremiumHeader(eyebrow: "IMUN / COACH",
                              title: "Train with purpose.",
                              subtitle: "One plan. Clear progress. Better decisions.")
                if !coach.signedIn { PremiumLogin() }

                HCCard(accent: HCDesign.electric) {
                    HStack(spacing: 19) {
                        HCProgressRing(progress: completion,
                                       value: plannedSets > 0 ? "\(min(completedSets, plannedSets))/\(plannedSets)" : "—",
                                       subtitle: "Sets done")
                        VStack(alignment: .leading, spacing: 9) {
                            HCInsightChip(title: "TODAY'S FOCUS",
                                          symbol: "sparkle",
                                          tint: HCDesign.electric)
                            Text(lift?.title ?? run?.title ?? "Your next session")
                                .font(HCDesign.display(20))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(plannedSets > 0 ?
                                 "Working-set progress is calculated from your recorded results." :
                                 "Your schedule comes from the iPhone and Command Center.")
                                .font(.system(size: 12))
                                .foregroundStyle(HCDesign.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }

                HCSectionTitle(title: "Today's schedule",
                               detail: Date().formatted(.dateTime.weekday(.wide)))
                HCCard {
                    VStack(spacing: 13) {
                        scheduleRow(title: "Weightlifting",
                                    session: lift?.title ?? "Nothing scheduled",
                                    symbol: "dumbbell.fill",
                                    detail: lift.map { "\($0.exercises.count) exercises · \(plannedSets) sets" } ?? "Rest / unscheduled")
                        Divider().overlay(HCDesign.outline)
                        scheduleRow(title: "Run",
                                    session: run?.title ?? "Nothing scheduled",
                                    symbol: "figure.run",
                                    detail: run?.targetDistanceMiles.map {
                                        String(format: "%.1f miles targeted", $0)
                                    } ?? "No distance target")
                    }
                }

                HCSectionTitle(title: "Coach briefing", detail: "Schedule-based")
                HCCard(accent: HCDesign.aqua) {
                    VStack(alignment: .leading, spacing: 11) {
                        HCInsightChip(title: "DAILY GUIDANCE",
                                      symbol: "text.bubble",
                                      tint: HCDesign.aqua)
                        Text(coachBriefing)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(HCDesign.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("This first version uses your real schedule, not generative AI or an invented recovery score.")
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                }

                HCSectionTitle(title: "Coach & app controls")
                NavigationLink {
                    PremiumSettingsPage()
                } label: {
                    HCCard {
                        HStack(spacing: 14) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(HCDesign.electric)
                                .frame(width: 44, height: 44)
                                .background(HCDesign.electric.opacity(0.11),
                                            in: RoundedRectangle(cornerRadius: 13))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Settings")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                Text("Appearance, coaching, connected apps and Watch")
                                    .font(.caption)
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            Spacer(minLength: 6)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                HCSyncStatus(pending: coach.cloudPendingCount,
                             saving: coach.savingPlan,
                             connected: coach.signedIn)
                Spacer(minLength: 30)
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PremiumSettingsPage()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(HCDesign.electric)
                }
                .accessibilityLabel("Coach settings")
            }
        }
    }

    private func scheduleRow(title: String, session: String,
                             symbol: String, detail: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .foregroundStyle(HCDesign.aqua)
                .frame(width: 27)
            VStack(alignment: .leading, spacing: 5) {
                Text(title.uppercased())
                    .font(HCDesign.label(10))
                    .tracking(1)
                    .foregroundStyle(HCDesign.secondary)
                Text(session)
                    .font(.system(size: 15, weight: .semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(HCDesign.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// All original settings, exports and integrations are preserved here.
private struct PremiumSettingsPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @EnvironmentObject private var tredict: HCTredictImporter
    @State private var tredictToken = ""
    @AppStorage("hcAggressiveProgression") private var aggressive = true
    @AppStorage("hcCoachingNotes") private var notes = ""
    @AppStorage("hcIncludeRecoveryExport") private var includeRecovery = false
    @AppStorage("hcAccentStyle") private var accentStyle = "crimson"
    @AppStorage("hcWeightIncrement") private var weightIncrement = 5.0
    @AppStorage("hcRestOverrideSeconds") private var restOverride = 0
    @AppStorage("hcWatchHaptics") private var watchHaptics = true

    private var export: String {
        var lines = ["# IMUN Training Export",
                     "Aggressive progression: \(aggressive)",
                     "## Coach notes", notes, "## Strength"]
        for s in coach.performanceHistory.sorted(by: { $0.date > $1.date }).prefix(250) {
            lines.append("\(s.date): \(s.exercise) · \(s.weightLb.formatted()) lb × \(s.reps) · RIR \(s.rir?.formatted() ?? "—")")
        }
        lines.append("## Running")
        for run in coach.runHistory.prefix(100) {
            let distance = run.distanceMeters.map { String(format: "%.2f mi", $0 / 1609.344) } ?? "—"
            var details = ["\(run.date): \(run.title)", distance, "source: \(run.source)"]
            if let elapsed = run.durationSeconds { details.append("time: \(hcDuration(elapsed))") }
            if let avgHR = run.averageBPM { details.append("avg HR: \(Int(avgHR)) bpm") }
            if let peak = run.maxBPM { details.append("max HR: \(Int(peak)) bpm") }
            if let kcal = run.activeCalories { details.append("active energy: \(Int(kcal)) kcal") }
            if let power = run.averagePowerWatts { details.append("running power: \(Int(power)) W") }
            if let cadence = run.averageCadenceSPM { details.append("cadence: \(Int(cadence)) spm") }
            if let elevation = run.elevationGainMeters { details.append("ascent: \(Int(elevation)) m") }
            if !run.splits.isEmpty {
                details.append("actual lap events: " + run.splits.map {
                    "lap \($0.index) \(hcDuration($0.elapsedSeconds))"
                }.joined(separator: ", "))
            }
            lines.append(details.joined(separator: " · "))
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
                PremiumHeader(eyebrow: "COACH / SETTINGS",
                              title: "Your preferences.",
                              subtitle: "Fine-tune your coaching, appearance and connections.")
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
                HCCard {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("SO RUN, THAT YE MAY OBTAIN.")
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundStyle(HCDesign.ink)
                        Text("1 Corinthians 9:24–27")
                            .font(HCDesign.label(11))
                            .foregroundStyle(HCDesign.electric)
                        Text("Discipline in training. Purpose in every effort.")
                            .font(.caption)
                            .foregroundStyle(HCDesign.secondary)
                        DisclosureGroup("READ THE PASSAGE · KJV") {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("24 · Know ye not that they which run in a race run all, but one receiveth the prize? So run, that ye may obtain.")
                                Text("25 · And every man that striveth for the mastery is temperate in all things. Now they do it to obtain a corruptible crown; but we an incorruptible.")
                                Text("26 · I therefore so run, not as uncertainly; so fight I, not as one that beateth the air:")
                                Text("27 · But I keep under my body, and bring it into subjection: lest that by any means, when I have preached to others, I myself should be a castaway.")
                            }
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(HCDesign.secondary)
                            .padding(.vertical, 8)
                        }
                        .font(HCDesign.label(11))
                        .tint(HCDesign.electric)
                    }
                }
                HCSectionTitle(title: "Appearance", detail: "Pick your accent")
                HCCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "paintpalette.fill")
                                .font(.title2)
                                .foregroundStyle(HCDesign.electric)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("YOUR LOOK").font(HCDesign.label(11)).tracking(1)
                                Text("Crimson + White by default")
                                    .font(.caption).foregroundStyle(HCDesign.secondary)
                            }
                        }
                        HStack(spacing: 9) {
                            accentTile(id: "crimson", name: "Crimson",
                                       tint: Color(red: 0.83, green: 0.20, blue: 0.31))
                            accentTile(id: "white", name: "White", tint: .white)
                            accentTile(id: "lime", name: "Lime",
                                       tint: Color(red: 0.76, green: 0.98, blue: 0.43))
                            accentTile(id: "aqua", name: "Aqua",
                                       tint: Color(red: 0.41, green: 0.85, blue: 0.82))
                        }
                        Text("The dark background and clear white typography stay consistent. Accent choices sync to your Apple Watch.")
                            .font(.caption2).foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Workout controls")
                HCCard {
                    VStack(alignment: .leading, spacing: 15) {
                        Picker("Weight step", selection: $weightIncrement) {
                            Text("2.5 lb").tag(2.5)
                            Text("5 lb").tag(5.0)
                            Text("10 lb").tag(10.0)
                        }
                        .tint(HCDesign.electric)
                        Divider().overlay(HCDesign.outline)
                        Picker("Rest after a set", selection: $restOverride) {
                            Text("Use workout plan").tag(0)
                            Text("60 sec").tag(60)
                            Text("90 sec").tag(90)
                            Text("2 min").tag(120)
                            Text("3 min").tag(180)
                        }
                        .tint(HCDesign.electric)
                        Divider().overlay(HCDesign.outline)
                        Toggle("Haptic alerts on the Watch", isOn: $watchHaptics)
                            .tint(HCDesign.electric)
                        Text("Changes are saved automatically and sent to your Watch when paired.")
                            .font(.caption2).foregroundStyle(HCDesign.secondary)
                    }
                }
                .onChange(of: weightIncrement) { _, _ in coach.sendToWatch() }
                .onChange(of: restOverride) { _, _ in coach.sendToWatch() }
                .onChange(of: watchHaptics) { _, _ in coach.sendToWatch() }
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
                            .foregroundStyle(HCDesign.onAccent)
                            .padding(16)
                            .background(HCDesign.electric, in: RoundedRectangle(cornerRadius: 14))
                        }
                        Text("Only you decide whether and where to share this export.")
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Tredict / Garmin", detail: "Full-history personal connection")
                HCCard {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            Image(systemName: "waveform.path")
                                .foregroundStyle(HCDesign.electric)
                            Text(tredict.connected ? "Tredict connection saved" :
                                 "Connect your Tredict account")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Text("Use a read-only Personal API token from Tredict → Settings → Personal API. Choose activityRead and bodyvaluesRead. The token stays in your iPhone Keychain; training data is downloaded to this device.")
                            .font(.caption)
                            .foregroundStyle(HCDesign.secondary)
                        if !tredict.connected {
                            SecureField("Personal API token", text: $tredictToken)
                                .textContentType(.password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(HCDesign.raised,
                                            in: RoundedRectangle(cornerRadius: 12))
                            HCFilledButton(title: "CONNECT & IMPORT HISTORY",
                                           icon: "arrow.down.circle.fill",
                                           disabled: tredictToken.isEmpty || tredict.loading) {
                                tredict.connect(token: tredictToken)
                                tredictToken = ""
                            }
                        } else {
                            HCFilledButton(title: tredict.loading ? "IMPORTING HISTORY…" :
                                                "SYNC ALL TREDICT HISTORY",
                                           icon: "arrow.clockwise",
                                           disabled: tredict.loading) {
                                tredict.refresh()
                            }
                            HCOutlineButton(title: "Disconnect Tredict", icon: "xmark.circle") {
                                tredict.disconnect()
                            }
                        }
                        if tredict.loading { ProgressView().tint(HCDesign.electric) }
                        Text(tredict.status)
                            .font(.caption)
                            .foregroundStyle(HCDesign.secondary)
                        if tredict.snapshot.lastSync != nil {
                            Text("Imported \(tredict.snapshot.rawActivityCount) activities · " +
                                 "\(tredict.snapshot.recovery.count) recovery days")
                                .font(.system(size: 12, weight: .medium))
                            Text("Included: " + tredict.snapshot.dataTypes.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(HCDesign.secondary)
                        }
                        if let archive = tredict.archiveURL {
                            ShareLink(item: archive) {
                                Label("Export original Tredict data archive",
                                      systemImage: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HCDesign.electric)
                            }
                        }
                        Link(destination: URL(string: "https://www.tredict.com/faq/personal-api---connect-your-own-scripts-or-personal-applications/")!) {
                            Label("How to create a Tredict API token",
                                  systemImage: "arrow.up.right")
                                .font(.system(size: 12))
                        }
                    }
                }
                HCSectionTitle(title: "Connected training history")
                HCCard {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack(spacing: 8) {
                            HCMetricBlock(label: "Working sets",
                                          value: String(coach.performanceHistory.count))
                            HCMetricBlock(label: "Past sessions",
                                          value: String(coach.trainingActivities.count))
                        }
                        HStack(spacing: 8) {
                            HCMetricBlock(label: "Run records",
                                          value: String(coach.runHistory.count))
                            HCMetricBlock(label: "Recovery days",
                                          value: String(coach.recoveryHistory.count))
                        }
                        Text("IMUN uses the original Health Coach and Tredict records stored in your Command Center account. Recording sources are preserved; activity and recovery metrics are not combined into made-up values.")
                            .font(.caption)
                            .foregroundStyle(HCDesign.secondary)
                        HCOutlineButton(title: "Refresh all connected data",
                                        icon: "arrow.clockwise") {
                            coach.refresh(date: Date())
                        }
                        if let archive = coach.legacyArchiveURL {
                            ShareLink(item: archive) {
                                Label("Export original source archive",
                                      systemImage: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HCDesign.electric)
                                    .padding(.vertical, 6)
                            }
                            Text("Contains your full legacy planner and training state, plus available workout and recovery records. Sharing is your choice.")
                                .font(.caption2)
                                .foregroundStyle(HCDesign.secondary)
                        }
                        Link(destination: URL(string: "https://www.tredict.com/faq/garmin-connect---how-to-connect-and-synchronize-my-device/")!) {
                            Label("Tredict Garmin history import instructions",
                                  systemImage: "arrow.up.right")
                                .font(.system(size: 12, weight: .medium))
                        }
                        Text("Additional Garmin sessions must first be made available through Tredict and your Command Center integration. IMUN cannot read a separate Garmin or Tredict account without that connection.")
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
        .navigationTitle("Settings")
    }
    @ViewBuilder
    private func accentTile(id: String, name: String, tint: Color) -> some View {
        Button {
            accentStyle = id
            coach.sendToWatch()
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(HCDesign.raised)
                    Circle().fill(tint)
                        .frame(width: 23, height: 23)
                    if accentStyle == id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(id == "crimson" ? .white : HCDesign.canvas)
                    }
                }
                .frame(height: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(accentStyle == id ? tint : HCDesign.outline,
                                      lineWidth: accentStyle == id ? 2 : 1)
                }
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HCDesign.ink)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name + " accent color")
        .accessibilityAddTraits(accentStyle == id ? [.isSelected] : [])
    }

}
