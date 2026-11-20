import SwiftUI
import Charts
import HealthKit

struct PhoneContentView: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @State private var selectedDate = Date()
    @StateObject private var appleHealth = HCAppleHealthReader()

    var body: some View {
        TabView {
            NavigationStack { StrengthHome(date: $selectedDate) }
                .tabItem { Label("Strength", systemImage: "dumbbell.fill") }

            NavigationStack { RunHome(date: $selectedDate) }
                .tabItem { Label("Run", systemImage: "figure.run") }

            NavigationStack { ProgressHome() }
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }

            NavigationStack { RecoveryHome(reader: appleHealth) }
                .tabItem { Label("Recovery", systemImage: "heart.text.square.fill") }

            NavigationStack { CoachSettingsHome() }
                .tabItem { Label("IsAIah", systemImage: "bubble.left.and.text.bubble.right") }
        }
        .tint(.teal)
        .onChange(of: selectedDate) { _, date in coach.refresh(date: date) }
        .onAppear {
            if coach.signedIn && coach.workout == nil {
                coach.refresh(date: selectedDate)
            }
        }
    }
}

private struct SignInCard: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @State private var email = ""
    @State private var password = ""
    var body: some View {
        Section("Health Coach Sign In") {
            Text("Sign in with your existing Health Coach / Command Center account.")
                .foregroundStyle(.secondary)
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .autocorrectionDisabled()
            SecureField("Password", text: $password)
                .textContentType(.password)
            Button("Sign In") {
                coach.login(email: email, password: password, date: Date())
                password = ""
            }
            .disabled(coach.loading || email.isEmpty || password.isEmpty)
            Text(coach.status).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct TrainingDayPicker: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Binding var date: Date

    var body: some View {
        Section("Training Date") {
            DatePicker("Selected day", selection: $date, displayedComponents: .date)
            HStack {
                Button("Today") { date = Date(); coach.refresh(date: date) }
                Spacer()
                Button("Refresh") { coach.refresh(date: date) }
                    .disabled(coach.loading)
            }
        }
    }
}

private struct StrengthHome: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Binding var date: Date

    @State private var newName = "Strength Workout"
    @State private var titleDraft = ""
    @State private var showLibrary = false
    @State private var showNewSession = false
    @AppStorage("hcAggressiveProgression") private var aggressive = true

    private var session: HCWorkout? { coach.workout }

    var body: some View {
        List {
            TrainingDayPicker(date: $date)

            if !coach.signedIn { SignInCard() }

            if let session {
                Section("Workout Overview") {
                    Text(session.title).font(.title3.weight(.bold))
                    Text("\(session.exercises.count) exercises · \(session.prescribedSetCount) work sets")
                        .foregroundStyle(.secondary)
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        if let started = coach.phoneSessionStartedAt {
                            Text("Elapsed: \(clockText(timeline.date.timeIntervalSince(started)))")
                                .font(.headline.monospacedDigit())
                        }
                    }
                    if coach.phoneSessionStartedAt == nil {
                        Button("Start Strength Workout") { coach.startPhoneWorkout() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Finish Strength Workout", role: .destructive) {
                            coach.finishPhoneWorkout()
                        }
                        .disabled(coach.phoneSetStartedAt != nil)
                    }
                    Button {
                        coach.sendToWatch()
                    } label: {
                        Label("Send to Apple Watch", systemImage: "applewatch")
                    }
                    TextField("Workout title", text: $titleDraft)
                        .textInputAutocapitalization(.words)
                    Button("Save Workout Name") {
                        guard !titleDraft.trimmingCharacters(in:.whitespaces).isEmpty else { return }
                        saveSession(title: titleDraft, exercises: session.exercises)
                    }
                }

                Section("Exercise Editor") {
                    if session.exercises.isEmpty {
                        Text("No exercises yet. Use Add Exercise to build today's workout.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(session.exercises) { exercise in
                        NavigationLink {
                            StrengthExerciseDetails(exerciseID: exercise.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(exercise.name).font(.body.weight(.semibold))
                                HStack {
                                    Text("\(exercise.setSummary) × \(exercise.repDescription)")
                                    Spacer()
                                    let suggestion = coach.suggestion(for: exercise, on:session.date,
                                                                       aggressive:aggressive)
                                    if let suggested = exercise.suggestedWeightLb ?? suggestion.weightLb {
                                        Text("\(suggested.formatted()) lb\(suggestion.perDumbbell ? "/DB" : "")")
                                    } else {
                                        Text("Choose weight")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: removeExercises)
                    .onMove(perform: moveExercises)
                    Button {
                        showLibrary = true
                    } label: {
                        Label("Add Exercise from Library", systemImage: "plus.circle.fill")
                    }
                    .disabled(session.exercises.count >= 35)
                }
            } else {
                Section("No Strength Workout Scheduled") {
                    Text("You can create a session on any date without changing your regular split.")
                        .foregroundStyle(.secondary)
                    Button("Create Workout") { showNewSession = true }
                        .buttonStyle(.borderedProminent)
                }
            }

        }
        .navigationTitle("Strength")
        .toolbar { EditButton() }
        .sheet(isPresented:$showLibrary) {
            ExerciseLibraryPicker { item in
                guard let plan = coach.workout else { return }
                let index = (plan.exercises.map(\.exerciseIndex).max() ?? -1) + 1
                guard index <= 40 else { return }
                let draft = HCExercise(
                    id:UUID().uuidString,name:item.name,originalName:item.name,
                    exerciseIndex:index,
                    prescribedSets:HCExercise.isOneSidedName(item.name) ? 6 : 3,
                    repMin:8,repMax:12,
                    suggestedWeightLb:nil,restSeconds:120
                )
                let suggestion = coach.suggestion(for:draft,on:plan.date,aggressive:aggressive)
                var added = HCExercise(
                    id:draft.id,name:item.name,originalName:item.name,
                    exerciseIndex:index,
                    prescribedSets:HCExercise.isOneSidedName(item.name) ? 6 : 3,
                    repMin:8,repMax:12,
                    suggestedWeightLb:suggestion.weightLb,restSeconds:120
                )
                added.instructions = item.instructions
                saveSession(title:plan.title,exercises:plan.exercises+[added])
            }
        }
        .alert("New Strength Workout", isPresented:$showNewSession) {
            TextField("Workout name",text:$newName)
            Button("Create") { coach.newWorkout(date: date, title: newName) }
            Button("Cancel",role:.cancel) {}
        } message: {
            Text("This creates a new editable strength session for the selected day.")
        }
        .onAppear { titleDraft = coach.workout?.title ?? "" }
        .onChange(of: coach.workout?.id) { _,_ in titleDraft = coach.workout?.title ?? "" }
    }

    private func saveSession(title: String, exercises: [HCExercise]) {
        guard let plan = coach.workout else { return }
        coach.saveEditedWorkout(HCWorkout(id:plan.id,date:plan.date,
            sessionKey:plan.sessionKey,title:title,exercises:exercises,isPreview:false))
    }

    private func moveExercises(from source: IndexSet, to target: Int) {
        guard let session else { return }
        var updated = session.exercises
        updated.move(fromOffsets: source, toOffset: target)
        saveSession(title:session.title,exercises:updated)
    }

    private func removeExercises(at offsets: IndexSet) {
        guard let session else { return }
        var updated = session.exercises
        updated.remove(atOffsets:offsets)
        saveSession(title:session.title,exercises:updated)
    }
}

struct StrengthExerciseDetails: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hcAggressiveProgression") private var aggressive = true

    let exerciseID: String
    @State private var sets = 3
    @State private var minimum = 8
    @State private var maximum = 12
    @State private var rest = 120
    @State private var weightText = ""
    @State private var instructionText = ""
    @State private var newWeight = ""
    @State private var newReps = 8
    @State private var newRIR = 2
    @State private var workingSide: HCWorkingSide = .left
    @State private var movementMode = "auto"
    @State private var showSwap = false
    @State private var editingSet: HCLoggedSet?

    private var oneSidedMode: Bool {
        movementMode == "unilateral" ||
        (movementMode == "auto" &&
         HCExercise.isOneSidedName(exercise?.name ?? ""))
    }
    private var plan: HCWorkout? { coach.workout }
    private var exercise: HCExercise? {
        plan?.exercises.first { $0.id == exerciseID }
    }
    private var logged: [HCLoggedSet] {
        guard let plan else { return [] }
        return coach.loggedSets.filter {
            $0.workoutID == plan.id && $0.exerciseID == exerciseID
        }.sorted { $0.index < $1.index }
    }

    var body: some View {
        Form {
            if let exercise, let plan {
                Section("Exercise") {
                    Text(exercise.name).font(.title3.weight(.bold))
                    let library = HCExerciseLibrary.all.first {
                        HCProgramCatalog.normalized($0.name) == HCProgramCatalog.normalized(exercise.name)
                    }
                    if let library {
                        LabeledContent("Muscles", value:library.group)
                        LabeledContent("Equipment", value:library.equipment)
                    }
                    Text(exercise.instructions ?? library?.instructions ??
                         "Maintain controlled technique and a comfortable range of motion.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Swap Movement") { showSwap = true }
                }

                Section("Aggressive Progression") {
                    let suggestion = coach.suggestion(for:exercise,on:plan.date,aggressive:aggressive)
                    LabeledContent("Confidence", value:suggestion.confidence)
                    if let target=suggestion.weightLb {
                        Text("Suggested: \(target.formatted()) lb\(suggestion.perDumbbell ? " EACH dumbbell" : "")")
                            .font(.headline)
                        Button("Use Suggested Load") {
                            weightText = target.formatted()
                        }
                    } else {
                        Text("No defensible starting weight yet")
                            .foregroundStyle(.secondary)
                    }
                    Text(suggestion.explanation).font(.caption)
                    Text("This estimates a starting weight, not a guaranteed safe load. Log completed reps and RIR to calibrate the selected variation.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Plan Editor") {
                    Picker("Movement pattern", selection: $movementMode) {
                        Text("Auto detect").tag("auto")
                        Text("Both sides together").tag("bilateral")
                        Text("One side at a time").tag("unilateral")
                    }
                    .onChange(of: movementMode) { _, _ in
                        if oneSidedMode && !sets.isMultiple(of: 2) {
                            sets *= 2
                        }
                    }
                    Stepper(oneSidedMode ?
                            "Total sets: \(sets) (\(sets / 2) per side)" :
                            "Working sets: \(sets)",
                            value:$sets, in:oneSidedMode ? 2...24 : 1...12,
                            step:oneSidedMode ? 2 : 1)
                    if oneSidedMode {
                        Text("Six total sets means three left + three right.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Stepper("Minimum reps: \(minimum)",value:$minimum,in:1...30)
                    Stepper("Maximum reps: \(maximum)",value:$maximum,in:minimum...40)
                    Stepper("Rest: \(rest) seconds",value:$rest,in:15...360,step:15)
                    TextField("Suggested weight (lb; per dumbbell for DB lifts)",text:$weightText)
                        .keyboardType(.decimalPad)
                    Text("Technique instructions").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text:$instructionText).frame(minHeight:100)
                    Button("Save Set Targets and Instructions") { saveTargets() }
                        .buttonStyle(.borderedProminent)
                }

                Section("Log a Set on iPhone") {
                    TimelineView(.periodic(from: .now, by: 1)) { now in
                        if let time=coach.phoneSetStartedAt,
                           coach.phoneSetExerciseID == exercise.id {
                            Text("Set time: \(clockText(now.date.timeIntervalSince(time)))")
                                .font(.headline.monospacedDigit())
                        }
                        if let end=coach.phoneRestEndsAt {
                            Text("Rest: \(clockText(max(0,end.timeIntervalSince(now.date))))")
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                    TextField("Actual weight lb (leave empty for unrecorded)",text:$newWeight)
                        .keyboardType(.decimalPad)
                    if exercise.isUnilateral {
                        Picker("Working side", selection: $workingSide) {
                            Text("Left").tag(HCWorkingSide.left)
                            Text("Right").tag(HCWorkingSide.right)
                        }
                    }
                    Stepper("Actual reps: \(newReps)",value:$newReps,in:1...60)
                    Stepper("Actual RIR: \(newRIR)",value:$newRIR,in:0...6)
                    if coach.phoneSessionStartedAt == nil {
                        Button("Start Workout Clock") { coach.startPhoneWorkout() }
                    } else if coach.phoneSetStartedAt == nil {
                        Button("Start Set") {
                            coach.startPhoneSet(exercise:exercise)
                        }
                    } else if coach.phoneSetExerciseID == exerciseID {
                        Button("Stop & Save Set") {
                            coach.logFromPhone(exercise:exercise,
                                weightLb:Double(newWeight),reps:newReps,rir:Double(newRIR),
                                sideOverride:exercise.isUnilateral ? workingSide : nil)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Cancel Set",role:.destructive) { coach.cancelPhoneSet() }
                    } else {
                        Text("Finish your current set in the other exercise first.")
                            .font(.caption)
                    }
                    Button("Log Set Without Timer") {
                        coach.logFromPhone(exercise:exercise,
                            weightLb:Double(newWeight),reps:newReps,rir:Double(newRIR),
                                sideOverride:exercise.isUnilateral ? workingSide : nil)
                    }
                    if coach.phoneRestEndsAt != nil {
                        Button("Skip Rest") { coach.skipPhoneRest() }
                    }
                }

                Section("Completed Sets — Tap to Correct") {
                    if logged.isEmpty {
                        Text("No completed sets yet").foregroundStyle(.secondary)
                    }
                    ForEach(logged) { set in
                        Button {
                            editingSet = set
                        } label: {
                            HStack {
                                Text("Set \(set.index)" +
                                     (set.side.map { " · \($0.title)" } ?? ""))
                                Spacer()
                                Text("\(set.weightLb.map{$0.formatted()+" lb"} ?? "Unrecorded") × \(set.reps)")
                                Image(systemName:"pencil")
                            }
                        }
                        if let insight = set.motionInsight {
                            Text("IsAIah motion note · " + insight.note)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("MOVEMENT")
        .scrollContentBackground(.hidden)
        .background(HCDesign.canvas)
        .tint(HCDesign.electric)
        .sheet(isPresented:$showSwap) {
            ExerciseLibraryPicker(replacing: exercise) { item in swapTo(item) }
        }
        .sheet(item:$editingSet) { set in
            SetCorrectionSheet(entry:set)
                .environmentObject(coach)
        }
        .onAppear { loadFromExercise() }
    }

    private func loadFromExercise() {
        guard let e = exercise else { return }
        sets=e.isUnilateral && !e.prescribedSets.isMultiple(of: 2) ?
            e.prescribedSets * 2 : e.prescribedSets
        minimum=e.repMin;maximum=e.repMax
        movementMode=e.movementType ?? "auto"
        workingSide=logged.count.isMultiple(of: 2) ? .left : .right
        rest=e.restSeconds
        weightText=e.suggestedWeightLb.map{$0.formatted()} ?? ""
        instructionText=e.instructions ?? HCExerciseLibrary.all.first {
            HCProgramCatalog.normalized($0.name)==HCProgramCatalog.normalized(e.name)
        }?.instructions ?? ""
        newWeight=weightText
        newReps=e.repMin
    }

    private func update(_ revised: HCExercise) {
        guard let p=plan,
              let index=p.exercises.firstIndex(where:{$0.id==exerciseID}) else{return}
        var list=p.exercises
        list[index]=revised
        coach.saveEditedWorkout(HCWorkout(id:p.id,date:p.date,sessionKey:p.sessionKey,
                                         title:p.title,exercises:list,isPreview:false))
    }

    private func saveTargets() {
        guard let e=exercise else{return}
        var updated=HCExercise(id:e.id,name:e.name,originalName:e.originalName,
            exerciseIndex:e.exerciseIndex,prescribedSets:sets,
            repMin:minimum,repMax:max(maximum,minimum),
            suggestedWeightLb:Double(weightText),restSeconds:rest)
        updated.instructions=instructionText.isEmpty ? nil : instructionText
        updated.movementType=movementMode == "auto" ? nil : movementMode
        update(updated)
    }

    private func swapTo(_ item: HCLibraryExercise) {
        guard let e=exercise,let plan else{return}
        let prototype=HCExercise(id:e.id,name:item.name,originalName:item.name,
            exerciseIndex:e.exerciseIndex,prescribedSets:sets,
            repMin:minimum,repMax:maximum,suggestedWeightLb:nil,restSeconds:rest)
        let suggestion=coach.suggestion(for:prototype,on:plan.date,aggressive:aggressive)
        var swapped=HCExercise(id:e.id,name:item.name,originalName:item.name,
            exerciseIndex:e.exerciseIndex,prescribedSets:sets,
            repMin:minimum,repMax:maximum,
            suggestedWeightLb:suggestion.weightLb,restSeconds:rest)
        swapped.instructions=item.instructions
        swapped.movementType=nil
        // Converting a bilateral movement into a unilateral one should
        // create a left/right pair for each originally planned round.
        if swapped.isUnilateral && !e.isUnilateral {
            swapped = HCExercise(id:e.id,name:item.name,originalName:item.name,
                exerciseIndex:e.exerciseIndex,prescribedSets:sets * 2,
                repMin:minimum,repMax:maximum,
                suggestedWeightLb:suggestion.weightLb,restSeconds:rest,
                instructions:item.instructions)
        }
        update(swapped)
        dismiss()
    }
}

private struct SetCorrectionSheet: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Environment(\.dismiss) private var dismiss
    let entry: HCLoggedSet
    @State private var weight = ""
    @State private var reps = 8
    @State private var rir = 2

    var body: some View {
        NavigationStack {
            Form {
                Section("Correct Recorded Set") {
                    Text(entry.exerciseName)
                    TextField("Weight lb",text:$weight).keyboardType(.decimalPad)
                    Stepper("Reps: \(reps)",value:$reps,in:1...100)
                    Stepper("Reps in reserve: \(rir)",value:$rir,in:0...6)
                }
                Section {
                    Text("This corrects the existing set ID; it won't count the same set twice.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Set")
            .toolbar {
                ToolbarItem(placement:.cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement:.confirmationAction) {
                    Button("Save") {
                        coach.correctLoggedSet(id:entry.id,weightLb:Double(weight),
                                               reps:reps,rir:Double(rir))
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            weight=entry.weightLb.map{$0.formatted()} ?? ""
            reps=entry.reps
            rir=Int(entry.rir ?? 2)
        }
    }
}

/// Native iMun catalog browser, shared by the workout builder and Smart Swap.
/// Recommendations are local and explainable: muscle + movement family +
/// compatible equipment, never fabricated exercise equivalences.
struct ExerciseLibraryPicker: View {
    @Environment(\.dismiss) private var dismiss
    let replacing: HCExercise?
    let onSelect: (HCLibraryExercise) -> Void
    @State private var query = ""
    @State private var group = "All"
    @State private var movementKind = "All"
    @State private var suggestedOnly = true
    @State private var expandedID: String?
    @State private var showingCustom = false
    @State private var customName = ""
    @State private var customInstructions = ""
    @State private var customGroup = "Other"

    init(replacing: HCExercise? = nil,
         onSelect: @escaping (HCLibraryExercise) -> Void) {
        self.replacing = replacing
        self.onSelect = onSelect
        _suggestedOnly = State(initialValue: replacing != nil)
    }

    private var recommendations: [HCLibraryExercise] {
        guard let replacing else { return [] }
        return HCExerciseLibrary.alternatives(for: replacing, limit: 16)
    }

    private var filtered: [HCLibraryExercise] {
        let pool = replacing != nil && suggestedOnly ?
            recommendations : HCExerciseLibrary.all
        return pool.filter { item in
            (group == "All" || item.group == group) &&
            (movementKind == "All" || item.kind.lowercased() == movementKind.lowercased()) &&
            (query.isEmpty || [item.name, item.equipment, item.group,
                               item.primaryLabel, item.instructions]
                .contains(where: { $0.localizedCaseInsensitiveContains(query) }))
        }
    }

    private func pick(_ item: HCLibraryExercise) {
        onSelect(item)
        dismiss()
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(selected ? HCDesign.canvas : HCDesign.secondary)
                .padding(.horizontal, 13).padding(.vertical, 10)
                .background(selected ? HCDesign.electric : HCDesign.card,
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func resultCard(_ item: HCLibraryExercise, recommended: Bool) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 17))
                    .foregroundStyle(HCDesign.electric)
                    .frame(width: 39, height: 39)
                    .background(HCDesign.electric.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(HCDesign.ink)
                    Text(item.primaryLabel + "  ·  " + item.equipment)
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                }
                Spacer(minLength: 2)
                if recommended {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(HCDesign.aqua)
                }
            }
            Text(item.instructions)
                .font(.system(size: 12))
                .foregroundStyle(HCDesign.secondary)
                .lineLimit(expandedID == item.id ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            if expandedID == item.id {
                if !item.formTip.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("FORM & CONTROL")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.0).foregroundStyle(HCDesign.aqua)
                        Text(item.formTip)
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.ink)
                    }
                }
                Text(item.difficulty.capitalized + "  ·  " + item.kind.capitalized)
                    .font(.system(size: 10))
                    .foregroundStyle(HCDesign.secondary)
            }
            HStack(spacing: 10) {
                Button {
                    expandedID = expandedID == item.id ? nil : item.id
                } label: {
                    Label(expandedID == item.id ? "LESS" : "HOW TO",
                          systemImage: expandedID == item.id ? "chevron.up" : "book.closed")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(HCDesign.aqua)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                Spacer()
                Button { pick(item) } label: {
                    Label(replacing == nil ? "ADD" : "SWAP",
                          systemImage: replacing == nil ? "plus" :
                              "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .foregroundStyle(HCDesign.canvas)
                        .background(HCDesign.electric, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(HCDesign.card,
                    in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17)
            .strokeBorder(HCDesign.outline.opacity(0.65), lineWidth: 0.7))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 13) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(replacing == nil ? "MOVEMENT LIBRARY" : "SMART SWAP")
                            .font(.system(size: 25, weight: .heavy, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(HCDesign.ink)
                        Text(replacing == nil ?
                             "\(HCExerciseLibrary.all.count) exercises, ready offline" :
                             "Similar muscles · matched movement patterns")
                            .font(.subheadline).foregroundStyle(HCDesign.secondary)
                        if let replacing {
                            Text("REPLACING  ·  " + replacing.name.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(HCDesign.aqua)
                                .padding(.top, 6)
                            if let best = recommendations.first {
                                Button { pick(best) } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("TOP MATCH").font(.system(size: 10, weight: .bold))
                                            Text(best.name).font(.system(size: 15, weight: .bold))
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                    }
                                    .foregroundStyle(HCDesign.canvas)
                                    .padding(15)
                                    .background(HCDesign.electric,
                                                in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 6)
                            }
                        }
                    }
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(HCDesign.secondary)
                        TextField("Search exercises, muscles or equipment", text: $query)
                            .font(.system(size: 13))
                            .foregroundStyle(HCDesign.ink)
                            .tint(HCDesign.electric)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(HCDesign.secondary)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(HCDesign.card,
                                in: RoundedRectangle(cornerRadius: 12))
                    if replacing != nil {
                        HStack {
                            chip("Best matches", selected: suggestedOnly) {
                                suggestedOnly = true
                            }
                            chip("Full library", selected: !suggestedOnly) {
                                suggestedOnly = false
                                group = "All"
                            }
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(HCExerciseLibrary.groups, id: \.self) { name in
                                chip(name, selected: group == name) { group = name }
                            }
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(["All", "strength", "stretching", "plyometrics",
                                     "cardio", "strongman", "olympic weightlifting"],
                                    id: \.self) { name in
                                chip(name == "All" ? "Any style" : name,
                                     selected: movementKind == name) {
                                    movementKind = name
                                }
                            }
                        }
                    }
                    HStack {
                        Text("\(filtered.count) MOVEMENTS")
                            .font(.system(size: 10, weight: .bold)).tracking(1)
                            .foregroundStyle(HCDesign.secondary)
                        Spacer()
                        if replacing == nil {
                            Button("CUSTOM +") { showingCustom = true }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(HCDesign.aqua)
                        }
                    }
                    if filtered.isEmpty {
                        Text("No matches. Try clearing your muscle or style filters.")
                            .font(.subheadline)
                            .foregroundStyle(HCDesign.secondary)
                            .padding(22)
                    }
                    ForEach(filtered) { item in
                        resultCard(item, recommended: replacing != nil && suggestedOnly)
                    }
                    Text("Exercise instructions are informational. Start with appropriate loads and use a spotter where needed. Free Exercise DB content is public domain (Unlicense).")
                        .font(.system(size: 10))
                        .foregroundStyle(HCDesign.secondary)
                        .padding(.vertical, 12)
                }
                .padding(18)
            }
            .background(HCDesign.canvas.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(HCDesign.electric)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingCustom) {
            NavigationStack {
                Form {
                    TextField("Exercise name", text: $customName)
                    TextField("Muscle group", text: $customGroup)
                    Section("Steps and form cues") {
                        TextEditor(text: $customInstructions)
                            .frame(minHeight: 130)
                    }
                    Button("SAVE MOVEMENT") {
                        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        pick(HCLibraryExercise(name: name, group: customGroup,
                             equipment: "Custom", instructions: customInstructions))
                    }
                }
                .scrollContentBackground(.hidden)
                .background(HCDesign.canvas)
                .navigationTitle("Custom Movement")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("CANCEL") { showingCustom = false }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

private struct RunHome: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Binding var date: Date
    @State private var showStructuredRun = false

    private var selectedRun: HCProgressRun? {
        coach.runHistory.first { $0.date == HCPlanBuilder.dateString(date) }
    }

    var body: some View {
        List {
            TrainingDayPicker(date:$date)
            if !coach.signedIn { SignInCard() }
            Section("Today's Run") {
                if let plan=coach.runPlan {
                    Text(plan.title).font(.title2.weight(.bold))
                    if let miles=plan.targetDistanceMiles {
                        LabeledContent("Planned distance",value:"\(miles.formatted()) mi")
                    }
                    Text(plan.notes.isEmpty ? "No additional workout intervals provided." : plan.notes)
                        .font(.subheadline)
                    if plan.isCompleted {
                        Label("Marked completed in Command Center",systemImage:"checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("No running workout scheduled for this date.")
                        .foregroundStyle(.secondary)
                }
                Button("Build & Send Interval Run to Apple Watch") {
                    showStructuredRun = true
                }.disabled(coach.runPlan == nil)
            }
            if let run=selectedRun {
                Section("Actual Recorded Run") {
                    LabeledContent("Source",value:run.source)
                    if let distance=run.distanceMeters {
                        LabeledContent("Distance",value:String(format:"%.2f mi",distance/1609.344))
                    }
                    if let duration=run.durationSeconds {
                        LabeledContent("Elapsed",value:clockText(duration))
                    }
                    if let distance=run.distanceMeters,let time=run.durationSeconds,distance > 0 {
                        LabeledContent("Average pace",
                                       value:paceText(seconds:time,meters:distance))
                    }
                    if let bpm=run.averageBPM {
                        LabeledContent("Average HR",value:"\(Int(bpm.rounded())) bpm")
                    }
                    if run.splits.isEmpty {
                        Text("No measured lap splits in the connected record.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(run.splits) { split in
                            HStack {
                                Text("Split \(split.index)")
                                Spacer()
                                Text(clockText(split.elapsedSeconds))
                                if let d=split.distanceMeters {
                                    Text(String(format:"%.2f mi",d/1609.344))
                                }
                            }.font(.caption)
                        }
                    }
                }
            }
            Section("Recent Running History") {
                ForEach(Array(coach.runHistory.prefix(20))) { run in
                    VStack(alignment:.leading,spacing:4) {
                        HStack {
                            Text(run.date)
                            Spacer()
                            Text(run.distanceMeters.map{String(format:"%.2f mi",$0/1609.344)} ?? "—")
                        }.font(.subheadline.weight(.semibold))
                        Text("\(run.title) · \(run.source)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if coach.runHistory.isEmpty {
                    Text("Connect your history or finish a run on the watch.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Run")
        .sheet(isPresented: $showStructuredRun) {
            if let plan = coach.runPlan {
                IMUNStructuredRunEditor(plan: plan)
            }
        }
    }
}

private struct ProgressHome: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @State private var selectedMovement = ""

    private var allExercises: [String] {
        Array(Set(coach.performanceHistory.map{$0.exercise})).sorted()
    }
    private var exerciseHistory: [HCPerformanceSet] {
        let selected=selectedMovement.isEmpty ? (allExercises.first ?? "") : selectedMovement
        return coach.performanceHistory.filter{$0.exercise == selected}
            .sorted{$0.date < $1.date}
    }
    private var runningTotal: Double {
        coach.runHistory.compactMap{$0.distanceMeters}.reduce(0,+)/1609.344
    }

    var body: some View {
        List {
            Section("Your Progress") {
                HStack {
                    MetricChip(label:"Recorded runs",value:"\(coach.runHistory.count)")
                    MetricChip(label:"Run distance",value:String(format:"%.1f mi",runningTotal))
                    MetricChip(label:"Strength sets",value:"\(coach.performanceHistory.count)")
                }
                Text("Only recorded data counts. Imported workouts close in date, distance and duration are deduplicated.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Strength Progress") {
                if allExercises.isEmpty {
                    Text("No past completed sets available yet.")
                } else {
                    Picker("Exercise",selection:$selectedMovement) {
                        Text("Choose a movement").tag("")
                        ForEach(allExercises,id:\.self){Text($0).tag($0)}
                    }
                    let points=exerciseHistory.compactMap { h -> StrengthPlotPoint? in
                        guard let d=HCPlanBuilder.startOfDate(h.date) else{return nil}
                        return StrengthPlotPoint(date:d,weight:h.weightLb,reps:h.reps)
                    }
                    if !points.isEmpty {
                        Chart(points) { item in
                            PointMark(x:.value("Date",item.date),y:.value("Load lb",item.weight))
                                .foregroundStyle(.teal)
                        }
                        .chartYAxisLabel("Logged load (lb)")
                        .frame(height:220)
                    }
                    ForEach(Array(exerciseHistory.suffix(8).reversed()),id:\.self) { p in
                        HStack {
                            Text(p.date)
                            Spacer()
                            Text("\(p.weightLb.formatted()) lb × \(p.reps)")
                        }.font(.caption)
                    }
                }
            }
            Section("Running Progress") {
                let points=coach.runHistory.compactMap { p -> RunningPlotPoint? in
                    guard let d=HCPlanBuilder.startOfDate(p.date),
                          let meters=p.distanceMeters else{return nil}
                    return RunningPlotPoint(date:d,miles:meters/1609.344)
                }
                if !points.isEmpty {
                    Chart(points) { item in
                        BarMark(x:.value("Date",item.date,unit:.day),
                                y:.value("Miles",item.miles))
                    }
                    .frame(height:220)
                } else {
                    Text("No measured run distances available.")
                }
                ForEach(Array(coach.runHistory.prefix(8))) { run in
                    HStack {
                        Text(run.date)
                        Spacer()
                        Text(run.distanceMeters.map{String(format:"%.2f mi",$0/1609.344)} ?? "No distance")
                    }.font(.caption)
                }
            }
            Section {
                Text("Exercise weights across different machines or implements are not interchangeable. A dumbbell load is tracked per dumbbell; the chart does not pretend machine and barbell totals are equal.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Progress")
    }
}

private struct StrengthPlotPoint: Identifiable {
    let id=UUID()
    let date:Date
    let weight:Double
    let reps:Int
}
private struct RunningPlotPoint: Identifiable {
    let id=UUID()
    let date:Date
    let miles:Double
}

private struct MetricChip: View {
    let label:String
    let value:String
    var body:some View {
        VStack(alignment:.leading,spacing:4) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth:.infinity,alignment:.leading)
    }
}

private struct RecoveryHome: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @ObservedObject var reader: HCAppleHealthReader

    var body: some View {
        List {
            Section("Apple Watch & WHOOP Through Apple Health") {
                Button {
                    reader.connect()
                } label: {
                    Label("Read Apple Health Measurements",systemImage:"heart.text.square")
                }
                Text(reader.status).font(.caption).foregroundStyle(.secondary)
                ForEach(reader.metrics) { m in
                    VStack(alignment:.leading,spacing:4) {
                        HStack {
                            Text(m.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(m.value).font(.headline)
                        }
                        Text("\(m.source) · \(m.date)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if reader.metrics.isEmpty {
                    Text("Apple Health measurements appear here once you grant access. WHOOP readings only appear if WHOOP writes them to Apple Health.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Tredict / Garmin Recovery History") {
                if let day=coach.recoveryHistory.first {
                    LabeledContent("Latest saved date",value:day.date)
                    if let sleep=day.sleepSeconds {
                        LabeledContent("Sleep",value:clockText(sleep))
                    }
                    if let hrv=day.hrvMS {
                        LabeledContent("Overnight HRV (RMSSD)",value:"\(Int(hrv.rounded())) ms")
                    }
                    if let baseline=day.hrvBaselineMS {
                        LabeledContent("Tredict baseline",value:"\(Int(baseline.rounded())) ms")
                    }
                    if let low=day.dailyLowHR {
                        LabeledContent("Daily low HR",value:"\(Int(low.rounded())) bpm")
                    }
                    Text("Source: \(day.source)").font(.caption)
                } else {
                    Text("No Tredict recovery record currently available.")
                }
            }
            Section("Understanding the Sources") {
                Text("Apple Health HRV is commonly SDNN; Tredict overnight HRV is RMSSD. Do not compare their numbers directly or manufacture an overall readiness score. WHOOP's proprietary recovery score requires a separate authorized WHOOP integration.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Recovery")
    }
}

private struct CoachSettingsHome: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @AppStorage("hcAggressiveProgression") private var aggressive = true
    @AppStorage("hcCoachingNotes") private var notes = ""
    @AppStorage("hcIncludeRecoveryExport") private var includeRecovery = false

    private var exportText:String {
        var lines=[
            "# Health Coach Training Export",
            "This is user-selected training data for analysis, not medical advice.",
            "Aggressive progression: \(aggressive)",
            "## Coaching comments",notes,
            "## Strength sets"
        ]
        for s in coach.performanceHistory.sorted(by:{$0.date > $1.date}).prefix(250) {
            lines.append("\(s.date) | \(s.exercise) | \(s.weightLb.formatted()) lb × \(s.reps) | RIR \(s.rir.map{$0.formatted()} ?? "unrecorded")")
        }
        for s in coach.loggedSets.suffix(150) {
            lines.append("\(s.workoutDate) | \(s.exerciseName) | \(s.weightLb.map{$0.formatted()} ?? "—") lb × \(s.reps) | source \(s.source ?? "Apple Watch")")
        }
        lines.append("## Running")
        for r in coach.runHistory.prefix(200) {
            lines.append("\(r.date) | \(r.title) | \(r.distanceMeters.map{String(format:"%.2f mi",$0/1609.344)} ?? "—") | \(r.durationSeconds.map{clockText($0)} ?? "—") | \(r.source)")
        }
        if includeRecovery {
            lines.append("## Recovery (source-labeled)")
            for r in coach.recoveryHistory.prefix(60) {
                lines.append("\(r.date): sleep \(r.sleepSeconds.map{clockText($0)} ?? "—"), HRV-RMSSD \(r.hrvMS.map{$0.formatted()} ?? "—") ms, source \(r.source)")
            }
        }
        return lines.joined(separator:"\n")
    }

    var body:some View {
        Form {
            Section("Progression Preferences") {
                Toggle("Aggressive progression",isOn:$aggressive)
                Text("Evidence-informed: work up within the rep range first, increase weight after controlled performance at the top. Cross-equipment estimates show their confidence and can be overridden.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Comments for Your AI Coach") {
                TextEditor(text:$notes).frame(minHeight:160)
                Text("Record soreness, class workload, exercise substitutions, training goals, and what should change next week.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Export to AI / Save Training Data") {
                Toggle("Include recovery data",isOn:$includeRecovery)
                ShareLink(item:exportText,
                          subject:Text("Health Coach training export"),
                          message:Text("Review my training trends and recommend next sessions based on recorded evidence.")) {
                    Label("Share Training Export",systemImage:"square.and.arrow.up")
                }
                Text("Nothing is sent to an AI automatically. You decide when and where to share the export.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Connection & Sync") {
                LabeledContent("Cloud status",value:coach.signedIn ? "Signed in" : "Signed out")
                LabeledContent("Pending uploads",value:"\(coach.cloudPendingCount)")
                Button("Retry Workout & Set Sync") {
                    coach.retryPendingWorkout()
                    coach.retryPendingCloudSets()
                }
                Button("Send Selected Workout to Watch") { coach.sendToWatch() }
                if coach.signedIn {
                    Button("Sign Out",role:.destructive) { coach.logout() }
                } else {
                    SignInCard()
                }
            }
        }
        .navigationTitle("Coach & Settings")
    }
}

private func clockText(_ seconds:TimeInterval)->String {
    let t=max(0,Int(seconds))
    return String(format:"%02d:%02d:%02d",t/3600,(t%3600)/60,t%60)
}

private func paceText(seconds:Double,meters:Double)->String {
    guard meters>0 else{return "—"}
    let pace=Int((seconds*1609.344/meters).rounded())
    return String(format:"%d:%02d /mi",pace/60,pace%60)
}

// HealthKit is a permission-based catalog: the available categories depend on
// the user's devices, the data sources they have connected, and actual samples.
// A WHOOP reading written to Apple Health is attributed to WHOOP; the private
// WHOOP RMSSD / recovery/strain score requires the separate WHOOP OAuth API.
struct HCHealthMetric: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let source: String
    let date: String
    var category: String = "Vitals"
    var unit: String = ""
    var numericValue: Double? = nil
    var higherIsWorse: Bool = false
    var lowerIsWorse: Bool = false
}

struct HCHealthTrendSample: Identifiable {
    let name: String
    let source: String
    let date: String
    let value: Double
    var id: String { name + ":" + source + ":" + date }
}

/// Timestamp-preserving heart-rate samples. Only authorized, already-imported
/// HealthKit readings are used. Sources are publishers, not a guarantee of
/// physical sensor identity or clinical accuracy.
struct IMUNHeartRateObservation: Identifiable {
    let id: UUID
    let source: String
    let bundleID: String
    let start: Date
    let end: Date
    let bpm: Double

    var midpoint: Date {
        start.addingTimeInterval(end.timeIntervalSince(start) / 2)
    }
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

struct IMUNHeartRateAgreement: Identifiable {
    let first: String
    let second: String
    let pairs: Int
    let medianDifferenceBPM: Double
    let nearAgreementPercent: Double
    var id: String { first + "|" + second }
}

struct IMUNHeartRateSourceReport: Identifiable {
    let source: String
    let sampleCount: Int
    let uniqueMinutes: Int
    let comparedSamples: Int
    let unusualJumps: Int
    let pairedMedianDifferenceBPM: Double?
    var id: String { source }
}

struct IMUNWearableIntelligenceSnapshot {
    let primary: String
    let sources: [IMUNHeartRateSourceReport]
    let agreements: [IMUNHeartRateAgreement]
    let summary: String

    var alignedWindows: Int { agreements.reduce(0) { $0 + $1.pairs } }
    var coachingContext: String {
        let matches = agreements.prefix(8).map { item in
            String(format: "%@ vs %@: %d time-matched readings, median absolute difference %.1f bpm, %.0f%% within 5 bpm",
                   item.first, item.second, item.pairs,
                   item.medianDifferenceBPM, item.nearAgreementPercent)
        }.joined(separator: "; ")
        return "WEARABLE SOURCE AGREEMENT (on-device, latest 48 hours): " +
            "Preferred wearable: " + primary + ". " + summary + " " +
            (matches.isEmpty ? "No sufficiently aligned cross-source readings." : matches) +
            ". Source agreement, sampling frequency, and rapid changes are NOT accuracy validation. " +
            "Do not rank devices by measured accuracy without a calibrated reference. " +
            "Do not merge HRV methods or duplicate activity from multiple publishers."
    }
}

/// Evidence engine: same-time comparisons, not an LLM guessing sensor accuracy.
/// Cap each comparison to one-to-one matches within 30 seconds and short
/// sampling intervals. Never average away disagreement or substitute missing data.
enum IMUNWearableIntelligence {
    static func analyze(_ observations: [IMUNHeartRateObservation],
                        primary: String,
                        asOf date: Date = Date()) -> IMUNWearableIntelligenceSnapshot {
        let since = date.addingTimeInterval(-48 * 3600)
        let valid = observations.filter {
            $0.end >= since && $0.start <= date &&
            $0.bpm.isFinite && (30...240).contains($0.bpm) &&
            $0.duration >= 0 && $0.duration <= 120
        }
        let groups = Dictionary(grouping: valid, by: \.source)
        let names = groups.keys.sorted()
        var compared: [String: Int] = [:]
        var deviations: [String: [Double]] = [:]
        var agreements: [IMUNHeartRateAgreement] = []

        func median(_ input: [Double]) -> Double? {
            let values = input.sorted()
            guard !values.isEmpty else { return nil }
            let i = values.count / 2
            return values.count.isMultiple(of: 2)
                ? (values[i - 1] + values[i]) / 2 : values[i]
        }

        if names.count > 1 {
            for firstIndex in 0..<(names.count - 1) {
                for secondIndex in (firstIndex + 1)..<names.count {
                    let a = (groups[names[firstIndex]] ?? [])
                        .sorted { $0.midpoint < $1.midpoint }
                    let b = (groups[names[secondIndex]] ?? [])
                        .sorted { $0.midpoint < $1.midpoint }
                    var i = 0
                    var j = 0
                    var differences: [Double] = []
                    while i < a.count && j < b.count {
                        let gap = a[i].midpoint.timeIntervalSince(b[j].midpoint)
                        if abs(gap) <= 30 {
                            let diff = abs(a[i].bpm - b[j].bpm)
                            differences.append(diff)
                            deviations[names[firstIndex], default: []].append(diff)
                            deviations[names[secondIndex], default: []].append(diff)
                            compared[names[firstIndex], default: 0] += 1
                            compared[names[secondIndex], default: 0] += 1
                            i += 1
                            j += 1
                        } else if gap < 0 {
                            i += 1
                        } else {
                            j += 1
                        }
                    }
                    if differences.count >= 5, let center = median(differences) {
                        agreements.append(IMUNHeartRateAgreement(
                            first: names[firstIndex], second: names[secondIndex],
                            pairs: differences.count, medianDifferenceBPM: center,
                            nearAgreementPercent: 100 * Double(differences.filter {
                                $0 <= 5
                            }.count) / Double(differences.count)))
                    }
                }
            }
        }

        var reports: [IMUNHeartRateSourceReport] = []
        for name in names {
            let samples: [IMUNHeartRateObservation] = (groups[name] ?? [])
                .sorted { lhs, rhs in lhs.midpoint < rhs.midpoint }
            var jumps = 0
            if samples.count >= 2 {
                for index in 1..<samples.count {
                    let earlier = samples[index - 1]
                    let later = samples[index]
                    let gap = later.midpoint.timeIntervalSince(earlier.midpoint)
                    if gap > 0 && gap <= 15 &&
                        abs(later.bpm - earlier.bpm) > 40 {
                        jumps += 1
                    }
                }
            }
            let minuteBuckets: [Int] = samples.map { sample in
                Int(sample.midpoint.timeIntervalSince1970 / 60)
            }
            let center: Double? = median(deviations[name] ?? [])
            let matchedCount: Int = compared[name] ?? 0
            let sourceReport = IMUNHeartRateSourceReport(
                source: name, sampleCount: samples.count,
                uniqueMinutes: Set(minuteBuckets).count,
                comparedSamples: matchedCount,
                unusualJumps: jumps,
                pairedMedianDifferenceBPM: center)
            reports.append(sourceReport)
        }
        reports.sort { lhs, rhs in
            if lhs.sampleCount == rhs.sampleCount { return lhs.source < rhs.source }
            return lhs.sampleCount > rhs.sampleCount
        }

        let summary: String
        if reports.isEmpty {
            summary = "No recent, comparable heart-rate recordings are available."
        } else if reports.count == 1 {
            summary = "One heart-rate source is available. Additional sources are needed for simultaneous comparison."
        } else if let bestSupported = agreements.max(by: { $0.pairs < $1.pairs }) {
            summary = String(format:
                "%d aligned windows across %@ and %@; median disagreement %.1f bpm. This measures agreement, not which wearable is more accurate.",
                bestSupported.pairs, bestSupported.first,
                bestSupported.second, bestSupported.medianDifferenceBPM)
        } else {
            summary = "Multiple sources are connected, but there are not yet five short-interval recordings aligned closely enough to compare."
        }
        return IMUNWearableIntelligenceSnapshot(
            primary: primary, sources: reports,
            agreements: agreements.sorted { $0.pairs > $1.pairs },
            summary: summary)
    }
}


/// EITAN is a transparent personal wellness trend, not a medical diagnosis,
/// injury predictor, or another provider's proprietary recovery algorithm.
/// Samples remain source- and method-specific; a missing input is never zero.
enum IMUNEitanWellnessEngine {
    private struct Reading {
        let name: String
        let source: String
        let date: String
        let value: Double
    }
    private struct Assessment {
        let score: Int?
        let factors: [HCEitanFactor]
        let sourceCount: Int
        let coverage: String
    }

    static func evaluate(health: HCAppleHealthReader,
                         coach: PhoneWorkoutBridge,
                         preferredSource: String) -> HCEitanSnapshot {
        var samples: [Reading] = health.metricHistory.compactMap { item in
            guard item.value.isFinite,
                  HCEitanWearableSource.accepts(item.source,
                      preferred: preferredSource) else { return nil }
            return Reading(name: item.name, source: item.source,
                           date: item.date, value: item.value)
        }
        // Imported overnight RMSSD and Apple Health SDNN retain separate
        // labels, baselines, and source identities.
        for datum in coach.recoveryHistory
            where HCEitanWearableSource.accepts(datum.source,
                                                preferred: preferredSource) {
            if let hours = datum.sleepSeconds.map({ $0 / 3600 }), hours > 0 {
                samples.append(Reading(name: "Total asleep", source: datum.source,
                                       date: datum.date, value: hours))
            }
            if let hrv = datum.hrvMS, hrv > 0 {
                samples.append(Reading(name: "HRV · RMSSD", source: datum.source,
                                       date: datum.date, value: hrv))
            }
            if let low = datum.dailyLowHR, low > 0 {
                samples.append(Reading(name: "Daily low HR", source: datum.source,
                                       date: datum.date, value: low))
            }
        }
        let activityDays = Set(
            coach.loggedSets.map(\.workoutDate) +
            coach.cloudRecordedSets.map(\.workoutDate) +
            coach.runHistory.map(\.date) +
            coach.completedWatchRuns.map(\.date) +
            coach.trainingActivities.map(\.date)
        )
        let today = Date()
        let todayResult = assess(date: today, samples: samples,
                                 activityDays: activityDays,
                                 preferredSource: preferredSource)
        var streak = 0
        if let score = todayResult.score, score < 60 {
            streak = 1
            // Reconstruct prior days from actual recorded history, even when
            // the app was not opened each day. Missing days break the streak.
            for offset in 1...5 {
                guard let date = Calendar.current.date(byAdding: .day,
                                                       value: -offset, to: today)
                else { break }
                // One stale abnormal reading cannot create a fictitious
                // multi-day low streak. Require fresh daily sensor evidence.
                let dateKey = HCPlanBuilder.dateString(date)
                let recordedToday = samples.contains {
                    $0.date == dateKey &&
                    ["HRV · SDNN", "HRV · RMSSD", "Resting heart rate",
                     "Daily low HR", "Respiratory rate", "Wrist temperature"]
                        .contains($0.name) &&
                    HCEitanWearableSource.accepts($0.source,
                                                  preferred: preferredSource)
                }
                guard recordedToday else { break }
                let prior = assess(date: date, samples: samples,
                                   activityDays: activityDays,
                                   preferredSource: preferredSource)
                guard let value = prior.score, value < 60 else { break }
                streak += 1
            }
        }
        let coachingPlan = IMUNEitanTrainingCoach.evaluate(
            today: today, coach: coach, health: health,
            preferredSource: preferredSource, wellness: todayResult.score,
            lowDays: streak)
        var result = HCEitanSnapshot(
            date: HCPlanBuilder.dateString(today),
            value: todayResult.score,
            factors: todayResult.factors,
            status: todayResult.score == nil
                ? "Building your personal baseline" : coachingPlan.title,
            coaching: coachingPlan.message, consecutiveLowDays: streak,
            sourceCount: todayResult.sourceCount,
            coverage: todayResult.coverage)
        result.coachingPlan = coachingPlan
        result.primaryWearable = preferredSource
        return result
    }

    private static func assess(date: Date, samples: [Reading],
                               activityDays: Set<String>,
                               preferredSource: String) -> Assessment {
        let calendar = Calendar.current
        let targetDay = HCPlanBuilder.dateString(date)
        let earliestDay = HCPlanBuilder.dateString(
            calendar.date(byAdding: .day, value: -28, to: date) ?? date)
        let dayBefore = HCPlanBuilder.dateString(
            calendar.date(byAdding: .day, value: -1, to: date) ?? date)
        let maxTwoDaysAgo = HCPlanBuilder.dateString(
            calendar.date(byAdding: .day, value: -2, to: date) ?? date)
        let maxThreeDaysAgo = HCPlanBuilder.dateString(
            calendar.date(byAdding: .day, value: -3, to: date) ?? date)
        var parts: [HCEitanFactor] = []
        var sources = Set<String>()
        var baselineFactors = 0

        func clamp(_ value: Double) -> Int {
            Int(min(100, max(0, value)).rounded())
        }

        func addTrend(id: String, label: String, names: [String],
                      weight: Double, lowIsBetter: Bool,
                      newestAllowed: String, relativeScale: Double) {
            let matching = samples.filter { item in
                names.contains(item.name) && item.date <= targetDay &&
                item.date >= earliestDay && item.value > 0 &&
                HCEitanWearableSource.accepts(item.source,
                                             preferred: preferredSource)
            }
            // Every possible source/HRV method is evaluated independently.
            // Do not blend SDNN with RMSSD or duplicate same-day providers.
            let grouped = Dictionary(grouping: matching) {
                $0.name + "|" + $0.source
            }
            let choices: [(Reading, Double, Int)] = grouped.values.compactMap { entries in
                let byDay = Dictionary(grouping: entries, by: \.date)
                let medians = byDay.compactMap { day, values -> Reading? in
                    let sorted = values.map(\.value).sorted()
                    guard !sorted.isEmpty else { return nil }
                    let center = sorted.count / 2
                    let median = sorted.count.isMultiple(of: 2) ?
                        (sorted[center - 1] + sorted[center]) / 2 : sorted[center]
                    return Reading(name: values[0].name, source: values[0].source,
                                   date: day, value: median)
                }.sorted { $0.date > $1.date }
                guard let latest = medians.first, latest.date >= newestAllowed else {
                    return nil
                }
                let previous = medians.filter {
                    $0.date < latest.date && $0.date >= earliestDay
                }
                guard previous.count >= 5 else { return nil }
                let baseline = previous.map(\.value).sorted()
                let center = baseline.count / 2
                let median = baseline.count.isMultiple(of: 2) ?
                    (baseline[center - 1] + baseline[center]) / 2 : baseline[center]
                guard median > 0 else { return nil }
                return (latest, median, previous.count)
            }
            guard let chosen = choices.sorted(by: {
                if $0.0.date != $1.0.date { return $0.0.date > $1.0.date }
                return $0.2 > $1.2
            }).first else { return }
            let reading = chosen.0
            let deviation = (reading.value - chosen.1) / chosen.1
            let adjustment = (lowIsBetter ? -deviation : deviation) * relativeScale
            let score = clamp(82 + adjustment)
            let direction = deviation >= 0 ? "above" : "below"
            parts.append(HCEitanFactor(
                id: id, title: label, value: score, detail:
                String(format: "%.1f %@ %.1f%% %@ your %@ baseline (%.1f); recorded %@",
                       reading.value,
                       reading.name == "Respiratory rate" ? "breaths/min" :
                       reading.name.contains("HRV") ? "ms" : "bpm",
                       abs(deviation) * 100, direction, reading.source,
                       chosen.1, reading.date),
                weight: weight))
            sources.insert(reading.source)
            baselineFactors += 1
        }

        // Sleep duration is source-attributed and compared with a simple
        // 7.5–9 h reference rather than claiming to measure sleep quality.
        let sleeping = samples.filter {
            ($0.name == "Total asleep" || $0.name == "Sleep") &&
            $0.date <= targetDay && $0.date >= maxTwoDaysAgo &&
            $0.value >= 2 && $0.value <= 15 &&
            HCEitanWearableSource.accepts($0.source,
                                         preferred: preferredSource)
        }.sorted { $0.date > $1.date }
        if let latest = sleeping.first {
            let hours = latest.value
            let score = clamp(hours < 7.5 ? (hours / 7.5) * 95 :
                                  hours <= 9.5 ? 95 :
                                  95 - (hours - 9.5) * 10)
            parts.append(HCEitanFactor(
                id: "sleep", title: "Sleep", value: score,
                detail: String(format: "%.1f h of recorded sleep (%@, %@). Duration is one signal, not a sleep-quality diagnosis.",
                               hours, latest.source, latest.date),
                weight: 0.30))
            sources.insert(latest.source)
        }
        addTrend(id: "hrv", label: "HRV trend",
                 names: ["HRV · SDNN", "HRV · RMSSD"], weight: 0.27,
                 lowIsBetter: false, newestAllowed: maxThreeDaysAgo,
                 relativeScale: 125)
        addTrend(id: "restingHR", label: "Heart-rate trend",
                 names: ["Resting heart rate"], weight: 0.20,
                 lowIsBetter: true, newestAllowed: maxThreeDaysAgo,
                 relativeScale: 150)
        // Daily low heart rate is not resting heart rate; it is a fallback
        // with the same family weight but an explicit different label.
        if !parts.contains(where: { $0.id == "restingHR" }) {
            addTrend(id: "restingHR", label: "Daily low HR trend",
                     names: ["Daily low HR"], weight: 0.20,
                     lowIsBetter: true, newestAllowed: maxThreeDaysAgo,
                     relativeScale: 135)
        }
        addTrend(id: "respiration", label: "Breathing trend",
                 names: ["Respiratory rate"], weight: 0.08,
                 lowIsBetter: true, newestAllowed: maxThreeDaysAgo,
                 relativeScale: 145)

        // Wrist temperature is compared to its own baseline, in °C, not a
        // ratio of Celsius values (which have an arbitrary zero).
        let wrist = samples.filter {
            $0.name == "Wrist temperature" &&
            $0.date <= targetDay && $0.date >= earliestDay &&
            HCEitanWearableSource.accepts($0.source,
                                         preferred: preferredSource)
        }.sorted { $0.date > $1.date }
        if let latest = wrist.first, latest.date >= maxThreeDaysAgo {
            let historical = wrist.filter {
                $0.source == latest.source && $0.date < latest.date
            }
            let uniqueDays = Dictionary(grouping: historical, by: \.date)
                .compactMap { $0.value.first?.value }
            if uniqueDays.count >= 5 {
                let baseline = uniqueDays.reduce(0, +) / Double(uniqueDays.count)
                let change = abs(latest.value - baseline)
                parts.append(HCEitanFactor(id: "temperature",
                    title: "Temperature trend", value: clamp(88 - change * 32),
                    detail: String(format: "Wrist temperature %.2f°C; %.2f°C from personal %@ baseline.",
                                   latest.value, change, latest.source),
                    weight: 0.07))
                sources.insert(latest.source)
                baselineFactors += 1
            }
        }

        let prior21Start = HCPlanBuilder.dateString(
            calendar.date(byAdding: .day, value: -27, to: date) ?? date)
        let recent7Start = HCPlanBuilder.dateString(
            calendar.date(byAdding: .day, value: -6, to: date) ?? date)
        let before7 = HCPlanBuilder.dateString(
            calendar.date(byAdding: .day, value: -7, to: date) ?? date)
        let weeklyDays = activityDays.filter { $0 >= recent7Start && $0 <= targetDay }.count
        let priorDays = activityDays.filter { $0 >= prior21Start && $0 <= before7 }.count
        if priorDays >= 2 || weeklyDays > 0 {
            let weeklyReference = max(1, Double(priorDays) / 3)
            let spike = max(0, Double(weeklyDays) / weeklyReference - 1.4)
            let loadScore = clamp(86 - spike * 14 - (weeklyDays >= 6 ? 12 : 0))
            parts.append(HCEitanFactor(
                id: "load", title: "Training balance", value: loadScore,
                detail: "\(weeklyDays) training days in the last 7 vs \(priorDays) in the preceding 21. Workload estimate uses days, not set completion or measured intensity.",
                weight: 0.08))
        }
        // Activity is contextual training strain, never a reason to reward
        // exhaustion or punish a healthy rest day. Prefer recorded exercise
        // minutes to active energy and steps, never count all three twice.
        for activityName in ["Exercise", "Active energy", "Steps"] {
            let activityReadings = samples.filter {
                $0.name == activityName &&
                $0.date >= earliestDay && $0.date <= targetDay &&
                $0.value.isFinite && $0.value >= 0 &&
                HCEitanWearableSource.accepts($0.source,
                                             preferred: preferredSource)
            }
            let sourceGroups = Dictionary(grouping: activityReadings, by: \.source)
            var candidates: [(source: String, date: String,
                              recent: Double, prior: Double)] = []
            for (source, values) in sourceGroups {
                let byDay = Dictionary(grouping: values, by: \.date)
                let daily = byDay.compactMap { day, readings -> (String, Double)? in
                    let amounts = readings.map(\.value).sorted()
                    guard !amounts.isEmpty else { return nil }
                    let midpoint = amounts.count / 2
                    let median = amounts.count.isMultiple(of: 2) ?
                        (amounts[midpoint - 1] + amounts[midpoint]) / 2 :
                        amounts[midpoint]
                    return (day, median)
                }
                let recent = daily.filter { $0.0 >= recent7Start && $0.0 <= targetDay }
                let older = daily.filter { $0.0 >= prior21Start && $0.0 <= before7 }
                guard recent.count >= 4, older.count >= 10,
                      let latest = recent.map(\.0).max(),
                      latest >= maxThreeDaysAgo else { continue }
                let recentAverage = recent.reduce(0.0) { $0 + $1.1 } /
                    Double(recent.count)
                let oldAverage = older.reduce(0.0) { $0 + $1.1 } /
                    Double(older.count)
                guard oldAverage > 0 else { continue }
                candidates.append((source, latest, recentAverage, oldAverage))
            }
            guard let found = candidates.sorted(by: {
                if $0.date != $1.date { return $0.date > $1.date }
                return $0.source < $1.source
            }).first else { continue }
            let relative = found.recent / found.prior
            let score = clamp(86 - max(0, relative - 1.3) * 28)
            parts.append(HCEitanFactor(
                id: "activity", title: "Activity balance", value: score,
                detail: String(format: "%@: 7-day average %.0f vs earlier average %.0f (%@); unusually high volume is one recovery consideration.",
                               activityName, found.recent, found.prior, found.source),
                weight: 0.08))
            sources.insert(found.source)
            break
        }
        // No health-only score from a single sleep night or exercise count.
        // A score requires at least two physiological factors and a genuine
        // personal baseline trend. Remaining weights are renormalized.
        let physiologicalCount = parts.filter { $0.id != "load" }.count
        let isSufficient = physiologicalCount >= 2 && baselineFactors >= 1
        let sumWeights = parts.reduce(0) { $0 + $1.weight }
        let value: Int? = isSufficient && sumWeights > 0 ?
            clamp(parts.reduce(0) { $0 + Double($1.value) * $1.weight } / sumWeights) : nil
        let label = preferredSource == "Auto" ?
            "Automatic wearable sources" : preferredSource + " primary"
        let coverage = isSufficient ?
            label + " · \(physiologicalCount) signals · \(baselineFactors) same-source baseline trends" :
            label + " · requires two available wellness signals and at least five historical readings for a baseline; missing values are not substituted from other wearables"
        return Assessment(score: value, factors: parts,
                          sourceCount: sources.count, coverage: coverage)
    }
}

/// Longitudinal training context: record training frequency, observed hard
/// sessions, and repeated short sleep without pretending a single biomarker
/// predicts readiness or overtraining. No Health data is uploaded here.
private enum IMUNEitanTrainingCoach {
    private struct SleepNight {
        let source: String
        let date: String
        let hours: Double
    }

    static func evaluate(today: Date, coach: PhoneWorkoutBridge,
                         health: HCAppleHealthReader, preferredSource: String,
                         wellness: Int?, lowDays: Int) -> HCEitanCoachingPlan {
        let cal = Calendar.current
        func dateKey(_ offset: Int) -> String {
            HCPlanBuilder.dateString(
                cal.date(byAdding: .day, value: offset, to: today) ?? today)
        }
        let todayKey = dateKey(0)
        let start7 = dateKey(-6)
        let start28 = dateKey(-27)

        // Distinct recorded dates; an absent app log does not demonstrate
        // actual rest. Workout or run imports from two devices count once.
        let recordedDays = Set(
            coach.loggedSets.map(\.workoutDate) +
            coach.cloudRecordedSets.map(\.workoutDate) +
            coach.runHistory.map(\.date) +
            coach.completedWatchRuns.map {
                HCPlanBuilder.dateString($0.startedAt)
            } +
            coach.trainingActivities.map(\.date)
        ).filter { $0 >= start28 && $0 <= todayKey }
        let weekDays = recordedDays.filter { $0 >= start7 }.count
        // Today's planned workout is not treated as completed.
        let latestIndex = recordedDays.contains(todayKey) ? 0 : -1
        var streak = 0
        for offset in (0..<21).map({ latestIndex - $0 }) {
            if recordedDays.contains(dateKey(offset)) { streak += 1 }
            else { break }
        }

        // RIR and recorded session-RPE are effort evidence, not interchangeable
        // with daily step totals, calorie counts, or exercise duration.
        let allSets = Dictionary(grouping:
            (coach.loggedSets + coach.cloudRecordedSets).filter {
                $0.workoutDate >= start7 && $0.workoutDate <= todayKey
            }, by: \.id).compactMap { $0.value.first }
        var hardDayDates = Set(allSets.compactMap { row -> String? in
            guard let rir = row.rir, rir.isFinite, rir >= 0 && rir <= 1
            else { return nil }
            return row.workoutDate
        })
        for item in coach.trainingActivities {
            guard item.date >= start7 && item.date <= todayKey,
                  let exertion = item.perceivedEffort,
                  exertion.isFinite && exertion >= 7 && exertion <= 10 else {
                continue
            }
            hardDayDates.insert(item.date)
        }
        let hardDays = hardDayDates.count

        // Choose one consistent provider and day per night. HRV SDNN/RMSSD
        // remain separate in the EITAN wellness calculation.
        var raw: [SleepNight] = health.metricHistory.compactMap { item in
            guard HCEitanWearableSource.accepts(item.source,
                                                preferred: preferredSource),
                  item.name == "Total asleep", item.value >= 2,
                  item.value <= 15, item.value.isFinite,
                  item.date >= start7, item.date <= todayKey else { return nil }
            return SleepNight(source: item.source, date: item.date,
                              hours: item.value)
        }
        for reading in coach.recoveryHistory {
            guard HCEitanWearableSource.accepts(reading.source,
                                                preferred: preferredSource),
                  reading.date >= start7 && reading.date <= todayKey,
                  let seconds = reading.sleepSeconds,
                  seconds.isFinite, seconds >= 7200, seconds <= 54000 else {
                continue
            }
            raw.append(SleepNight(source: reading.source, date: reading.date,
                                  hours: seconds / 3600))
        }
        raw = raw.filter {
            HCEitanWearableSource.accepts($0.source,
                                         preferred: preferredSource)
        }
        let grouped = Dictionary(grouping: raw, by: \.source)
        let selected = grouped.values.sorted { a, b in
            let aDays = Set(a.map(\.date))
            let bDays = Set(b.map(\.date))
            if aDays.count != bDays.count { return aDays.count > bDays.count }
            return (a.map(\.date).max() ?? "") > (b.map(\.date).max() ?? "")
        }.first ?? []
        let perDay = Dictionary(grouping: selected, by: \.date)
        let nights = perDay.compactMap { _, readings -> Double? in
            let values = readings.map(\.hours).sorted()
            guard !values.isEmpty else { return nil }
            let center = values.count / 2
            return values.count.isMultiple(of: 2) ?
                (values[center - 1] + values[center]) / 2 : values[center]
        }
        let shortSleep = nights.count >= 4 ?
            nights.filter { $0 < 7 }.count : nil

        let style = UserDefaults.standard.string(forKey: "hcEitanCoachStyle")
            ?? "driven"
        return HCEitanCoachingPolicy.evaluate(
            wellness: wellness, lowDays: lowDays,
            streak: streak, trainingDays: weekDays,
            hardDays: hardDays, shortSleepNights: shortSleep,
            sleepObservations: nights.count,
            checkIn: coach.todayEitanCheckIn, style: style)
    }
}

private struct HCHealthCatalogItem {
    let identifier: String
    let name: String
    let category: String
    let unit: HKUnit
    let suffix: String
    let isDailySum: Bool
    var multiply: Double = 1
    var higherIsWorse: Bool = false
    var lowerIsWorse: Bool = false

    var type: HKQuantityType? {
        // Use the documented raw identifiers. HealthKit returns nil for a type
        // unavailable on the installed OS rather than crashing older devices.
        HKObjectType.quantityType(forIdentifier:
            HKQuantityTypeIdentifier(rawValue: "HKQuantityTypeIdentifier" + identifier))
    }
}

// Collect query results off the main thread and publish ONE coherent snapshot
// instead of invalidating the entire Health screen after every source sample.
private final class HCHealthReadBatch {
    private let lock = NSLock()
    private var loadedMetrics: [HCHealthMetric] = []
    private var loadedHistory: [HCHealthTrendSample] = []
    private var loadedHeartRates: [IMUNHeartRateObservation] = []

    func append(metric: HCHealthMetric, points: [HCHealthTrendSample]) {
        lock.lock()
        defer { lock.unlock() }
        loadedMetrics.append(metric)
        loadedHistory.append(contentsOf: points)
    }

    func appendHeartRates(_ observations: [IMUNHeartRateObservation]) {
        lock.lock()
        defer { lock.unlock() }
        loadedHeartRates.append(contentsOf: observations)
    }

    func snapshot() -> (metrics: [HCHealthMetric],
                        history: [HCHealthTrendSample],
                        heartRates: [IMUNHeartRateObservation]) {
        lock.lock()
        defer { lock.unlock() }
        return (loadedMetrics, loadedHistory, loadedHeartRates)
    }
}

final class HCAppleHealthReader: ObservableObject {
    @Published private(set) var metrics: [HCHealthMetric] = []
    @Published private(set) var metricHistory: [HCHealthTrendSample] = []
    @Published private(set) var heartRateObservations: [IMUNHeartRateObservation] = []
    @Published private(set) var status =
        "Connect Apple Health to view available measurements, trends, and sources."
    @Published private(set) var loading = false
    private let store = HKHealthStore()
    private var generation = 0
    private var lastRefreshStartedAt: Date?
    private let automaticRefreshInterval: TimeInterval = 5 * 60

    // Broad data catalog. Metrics are only displayed when samples actually exist;
    // no empty data is replaced with a guess or artificial zero.
    // Count/energy/distance values are shown as recorded daily sums.
    private let catalog: [HCHealthCatalogItem] = [
        .init(identifier:"HeartRate", name:"Heart rate", category:"Heart & Vitals",
              unit:HKUnit.count().unitDivided(by:.minute()), suffix:"bpm", isDailySum:false),
        .init(identifier:"RestingHeartRate", name:"Resting heart rate", category:"Heart & Vitals",
              unit:HKUnit.count().unitDivided(by:.minute()), suffix:"bpm", isDailySum:false,
              higherIsWorse:true),
        .init(identifier:"HeartRateVariabilitySDNN", name:"HRV · SDNN", category:"Heart & Vitals",
              unit:HKUnit.secondUnit(with:.milli), suffix:"ms", isDailySum:false,
              lowerIsWorse:true),
        .init(identifier:"WalkingHeartRateAverage", name:"Walking heart rate", category:"Heart & Vitals",
              unit:HKUnit.count().unitDivided(by:.minute()), suffix:"bpm", isDailySum:false),
        .init(identifier:"HeartRateRecoveryOneMinute", name:"1-min heart rate recovery", category:"Heart & Vitals",
              unit:HKUnit.count().unitDivided(by:.minute()), suffix:"bpm", isDailySum:false),
        .init(identifier:"RespiratoryRate", name:"Respiratory rate", category:"Heart & Vitals",
              unit:HKUnit.count().unitDivided(by:.minute()), suffix:"breaths/min",
              isDailySum:false,higherIsWorse:true),
        .init(identifier:"OxygenSaturation", name:"Blood oxygen", category:"Heart & Vitals",
              unit:HKUnit.percent(), suffix:"%", isDailySum:false, multiply:100),
        .init(identifier:"BloodPressureSystolic", name:"Systolic BP", category:"Heart & Vitals",
              unit:HKUnit.millimeterOfMercury(), suffix:"mmHg", isDailySum:false),
        .init(identifier:"BloodPressureDiastolic", name:"Diastolic BP", category:"Heart & Vitals",
              unit:HKUnit.millimeterOfMercury(), suffix:"mmHg", isDailySum:false),
        .init(identifier:"VO2Max", name:"VO₂ max", category:"Heart & Vitals",
              unit:HKUnit.literUnit(with:.milli)
                  .unitDivided(by: HKUnit.gramUnit(with:.kilo))
                  .unitDivided(by: HKUnit.minute()), suffix:"mL/kg/min", isDailySum:false),
        .init(identifier:"BodyTemperature", name:"Body temperature", category:"Heart & Vitals",
              unit:HKUnit.degreeCelsius(), suffix:"°C", isDailySum:false),
        .init(identifier:"BasalBodyTemperature", name:"Basal temperature", category:"Heart & Vitals",
              unit:HKUnit.degreeCelsius(), suffix:"°C", isDailySum:false),
        .init(identifier:"AppleSleepingWristTemperature", name:"Wrist temperature", category:"Heart & Vitals",
              unit:HKUnit.degreeCelsius(), suffix:"°C", isDailySum:false),

        .init(identifier:"StepCount", name:"Steps", category:"Activity & Energy",
              unit:HKUnit.count(), suffix:"steps", isDailySum:true),
        .init(identifier:"DistanceWalkingRunning", name:"Walking + running distance",
              category:"Activity & Energy",unit:HKUnit.mile(), suffix:"mi",isDailySum:true),
        .init(identifier:"ActiveEnergyBurned",name:"Active energy",category:"Activity & Energy",
              unit:HKUnit.kilocalorie(),suffix:"kcal",isDailySum:true),
        .init(identifier:"BasalEnergyBurned",name:"Resting energy",category:"Activity & Energy",
              unit:HKUnit.kilocalorie(),suffix:"kcal",isDailySum:true),
        .init(identifier:"AppleExerciseTime",name:"Exercise",category:"Activity & Energy",
              unit:HKUnit.minute(),suffix:"min",isDailySum:true),
        .init(identifier:"AppleMoveTime",name:"Move time",category:"Activity & Energy",
              unit:HKUnit.minute(),suffix:"min",isDailySum:true),
        .init(identifier:"AppleStandTime",name:"Standing time",category:"Activity & Energy",
              unit:HKUnit.minute(),suffix:"min",isDailySum:true),
        .init(identifier:"FlightsClimbed",name:"Flights climbed",category:"Activity & Energy",
              unit:HKUnit.count(),suffix:"flights",isDailySum:true),
        .init(identifier:"PhysicalEffort",name:"Physical effort",category:"Activity & Energy",
              unit:HKUnit.kilocalorie()
                  .unitDivided(by: HKUnit.hour())
                  .unitDivided(by: HKUnit.gramUnit(with:.kilo)),suffix:"MET",isDailySum:false),

        .init(identifier:"RunningSpeed",name:"Running speed",category:"Running & Cycling",
              unit:HKUnit.meter().unitDivided(by:.second()),suffix:"m/s",isDailySum:false),
        .init(identifier:"RunningPower",name:"Running power",category:"Running & Cycling",
              unit:HKUnit.watt(),suffix:"W",isDailySum:false),
        .init(identifier:"RunningStrideLength",name:"Running stride",category:"Running & Cycling",
              unit:HKUnit.meter(),suffix:"m",isDailySum:false),
        .init(identifier:"RunningVerticalOscillation",name:"Vertical oscillation",
              category:"Running & Cycling",unit:HKUnit.meterUnit(with: .centi),suffix:"cm",isDailySum:false),
        .init(identifier:"RunningGroundContactTime",name:"Ground contact time",
              category:"Running & Cycling",unit:HKUnit.secondUnit(with:.milli),
              suffix:"ms",isDailySum:false),
        .init(identifier:"DistanceCycling",name:"Cycling distance",category:"Running & Cycling",
              unit:HKUnit.mile(),suffix:"mi",isDailySum:true),
        .init(identifier:"CyclingPower",name:"Cycling power",category:"Running & Cycling",
              unit:HKUnit.watt(),suffix:"W",isDailySum:false),
        .init(identifier:"CyclingSpeed",name:"Cycling speed",category:"Running & Cycling",
              unit:HKUnit.meter().unitDivided(by:.second()),suffix:"m/s",isDailySum:false),
        .init(identifier:"CyclingCadence",name:"Cycling cadence",category:"Running & Cycling",
              unit:HKUnit.count().unitDivided(by:.minute()),suffix:"rpm",isDailySum:false),
        .init(identifier:"CyclingFunctionalThresholdPower",name:"Cycling FTP",
              category:"Running & Cycling",unit:HKUnit.watt(),suffix:"W",isDailySum:false),
        .init(identifier:"DistanceSwimming",name:"Swimming distance",category:"Running & Cycling",
              unit:HKUnit.meter(),suffix:"m",isDailySum:true),
        .init(identifier:"SwimmingStrokeCount",name:"Swim strokes",category:"Running & Cycling",
              unit:HKUnit.count(),suffix:"strokes",isDailySum:true),

        .init(identifier:"WalkingSpeed",name:"Walking speed",category:"Mobility",
              unit:HKUnit.meter().unitDivided(by:.second()),suffix:"m/s",isDailySum:false),
        .init(identifier:"WalkingStepLength",name:"Walking step length",category:"Mobility",
              unit:HKUnit.meter(),suffix:"m",isDailySum:false),
        .init(identifier:"WalkingAsymmetryPercentage",name:"Walking asymmetry",
              category:"Mobility",unit:HKUnit.percent(),suffix:"%",isDailySum:false,multiply:100),
        .init(identifier:"WalkingDoubleSupportPercentage",name:"Double support",
              category:"Mobility",unit:HKUnit.percent(),suffix:"%",isDailySum:false,multiply:100),
        .init(identifier:"AppleWalkingSteadiness",name:"Walking steadiness",
              category:"Mobility",unit:HKUnit.percent(),suffix:"%",isDailySum:false,multiply:100),
        .init(identifier:"SixMinuteWalkTestDistance",name:"Six-minute walk",
              category:"Mobility",unit:HKUnit.meter(),suffix:"m",isDailySum:false),
        .init(identifier:"StairAscentSpeed",name:"Stair ascent",category:"Mobility",
              unit:HKUnit.meter().unitDivided(by:.second()),suffix:"m/s",isDailySum:false),
        .init(identifier:"StairDescentSpeed",name:"Stair descent",category:"Mobility",
              unit:HKUnit.meter().unitDivided(by:.second()),suffix:"m/s",isDailySum:false),

        .init(identifier:"BodyMass",name:"Weight",category:"Body Measurements",
              unit:HKUnit.pound(),suffix:"lb",isDailySum:false),
        .init(identifier:"LeanBodyMass",name:"Lean mass",category:"Body Measurements",
              unit:HKUnit.pound(),suffix:"lb",isDailySum:false),
        .init(identifier:"BodyFatPercentage",name:"Body fat",category:"Body Measurements",
              unit:HKUnit.percent(),suffix:"%",isDailySum:false,multiply:100),
        .init(identifier:"BodyMassIndex",name:"BMI",category:"Body Measurements",
              unit:HKUnit.count(),suffix:"",isDailySum:false),
        .init(identifier:"Height",name:"Height",category:"Body Measurements",
              unit:HKUnit.meter(),suffix:"m",isDailySum:false),
        .init(identifier:"WaistCircumference",name:"Waist circumference",
              category:"Body Measurements",unit:HKUnit.meterUnit(with: .centi),suffix:"cm",
              isDailySum:false),
        .init(identifier:"BloodGlucose",name:"Blood glucose",category:"Metabolic & Nutrition",
              unit:HKUnit(from:"mg/dL"),suffix:"mg/dL",isDailySum:false),
        .init(identifier:"DietaryEnergyConsumed",name:"Food energy",category:"Metabolic & Nutrition",
              unit:HKUnit.kilocalorie(),suffix:"kcal",isDailySum:true),
        .init(identifier:"DietaryWater",name:"Water",category:"Metabolic & Nutrition",
              unit:HKUnit.liter(),suffix:"L",isDailySum:true),
        .init(identifier:"DietaryProtein",name:"Protein",category:"Metabolic & Nutrition",
              unit:HKUnit.gram(),suffix:"g",isDailySum:true),
        .init(identifier:"DietaryCarbohydrates",name:"Carbohydrates",category:"Metabolic & Nutrition",
              unit:HKUnit.gram(),suffix:"g",isDailySum:true),
        .init(identifier:"DietaryFatTotal",name:"Dietary fat",category:"Metabolic & Nutrition",
              unit:HKUnit.gram(),suffix:"g",isDailySum:true),
        .init(identifier:"DietaryFiber",name:"Fiber",category:"Metabolic & Nutrition",
              unit:HKUnit.gram(),suffix:"g",isDailySum:true),
        .init(identifier:"DietarySodium",name:"Sodium",category:"Metabolic & Nutrition",
              unit:HKUnit.gramUnit(with:.milli),suffix:"mg",isDailySum:true),
        .init(identifier:"DietaryCaffeine",name:"Caffeine",category:"Metabolic & Nutrition",
              unit:HKUnit.gramUnit(with:.milli),suffix:"mg",isDailySum:true)
    ]

    /// One HealthKit permission flow covers biometrics, historical workouts
    /// and the associated running details. HealthKit does not disclose which
    /// read types were accepted: only verified imported records prove access.
    func connect(onRequestCompleted: (() -> Void)? = nil) {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "Apple Health is unavailable on this device."
            return
        }
        var types = Set<HKObjectType>()
        for metric in catalog {
            if let type = metric.type { types.insert(type) }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        types.insert(HKObjectType.workoutType())
        types.insert(HKSeriesType.workoutRoute())
        store.requestAuthorization(toShare: [], read: types) { [weak self] completed, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.status = "Apple Health request: " + error.localizedDescription
                    return
                }
                guard completed else {
                    self.status = "Apple Health request was not completed."
                    return
                }
                // This records completion of the request, not whether each
                // protected read category was granted.
                UserDefaults.standard.set(true, forKey: "hcHealthCatalogEnabled")
                UserDefaults.standard.set(true, forKey: "hcAutomaticRunImport")
                self.status = "Checking Apple Health for readable records…"
                self.refresh()
                onRequestCompleted?()
            }
        }
    }

    func refreshIfAuthorized(force: Bool = false) {
        guard UserDefaults.standard.bool(forKey: "hcHealthCatalogEnabled") else { return }
        guard !loading else { return }
        if !force, let last = lastRefreshStartedAt,
           Date().timeIntervalSince(last) < automaticRefreshInterval {
            return
        }
        refresh()
    }

    /// A scroll-independent snapshot of every currently loaded Health metric.
    /// The assistant receives this only if the athlete enables Health sharing
    /// and explicitly sends a message. No screen scraping or background upload.
    func isaiahHealthSnapshot(selectedCategory: String,
                              selectedMetric: String,
                              question: String,
                              primaryWearable: String = "Auto") -> String {
        let questionText = question.lowercased()
        let exerciseQuestion = ["run", "pace", "aerobic", "fitness",
                                "endurance", "vo2", "vo₂", "cycling",
                                "performance", "progress", "plateau"]
            .contains { questionText.contains($0) }
        // IsAIah needs cross-platform evidence: retain all sources. The
        // preferred device changes interpretive priority, not data visibility.
        // Different metrics and methods remain source-specific.
        func isTrainingMetric(_ metric: HCHealthMetric) -> Bool {
            metric.category == "Running & Cycling" ||
                metric.name.localizedCaseInsensitiveContains("VO2") ||
                metric.name.localizedCaseInsensitiveContains("VO₂")
        }
        let all = metrics.sorted {
            let a = ($0.category, $0.name, $0.source, $0.date)
            let b = ($1.category, $1.name, $1.source, $1.date)
            return a < b
        }
        guard !all.isEmpty else {
            return loading ? "Apple Health is still loading on this iPhone." :
                "No authorized Apple Health measurements are currently loaded. Historical records may still exist in another connected platform; do not claim no exercise."
        }

        var lines = ["APPLE HEALTH: \(all.count) source-attributed Health metric cards.",
                     "Preferred source for interpretation: " + primaryWearable + ". All authorized source measurements remain available for longitudinal comparison; do not choose Apple Watch by default, merge HRV methods, or infer the same metric for missing WHOOP days. Tredict workouts remain separate.",
                     "Selected Health category: " + selectedCategory,
                     "Selected Health metric: " + (selectedMetric.isEmpty ? "none" : selectedMetric),
                     "Values keep their own source, method, unit and recorded date; never merge unlike sources."]
        for metric in all {
            lines.append(metric.category + " | " + metric.name +
                         " | " + metric.value + " | " +
                         metric.source + " | " + metric.date)
        }

        // Include history for whichever readings the question concerns, when
        // available. This is supplemental; all current readings appear above.
        let terms = (question + " " + selectedMetric).lowercased()
        let relevant = Set(all.filter { metric in
            let name = metric.name.lowercased()
            return terms.contains(name) ||
                ((terms.contains("hrv") || terms.contains("variability")) &&
                 name.contains("hrv")) ||
                (terms.contains("sleep") && name.contains("sleep")) ||
                ((terms.contains("heart") || terms.contains("pulse")) &&
                 name.contains("heart")) ||
                ((terms.contains("step") || terms.contains("activity")) &&
                 name.contains("step")) ||
                (exerciseQuestion && (isTrainingMetric(metric) ||
                    name.contains("resting heart") ||
                    name.contains("sleep")))
        }.map(\.name))
        let histories = Dictionary(grouping: metricHistory.filter {
            relevant.contains($0.name)
        }, by: { $0.name + " | " + $0.source })
        for name in histories.keys.sorted() {
            let ordered = (histories[name] ?? []).sorted { $0.date > $1.date }
            let fitnessSeries = exerciseQuestion &&
                (name.localizedCaseInsensitiveContains("VO2") ||
                 name.localizedCaseInsensitiveContains("VO₂"))
            let selected: [HCHealthTrendSample]
            if fitnessSeries && ordered.count > 14 {
                // Early and recent measurements both matter to a plateau
                // question, not only the last two weeks of data.
                selected = Array(ordered.prefix(9)) + Array(ordered.suffix(5))
            } else {
                selected = Array(ordered.prefix(14))
            }
            if !selected.isEmpty {
                lines.append("HISTORY " + name + ": " +
                    selected.map { $0.date + "=" +
                        String(format: "%.2f", $0.value) }
                        .joined(separator: ", "))
            }
        }
        if primaryWearable == "WHOOP" {
            lines.append("Important: WHOOP HRV/RMSSD is not written to Apple Health. No Apple Watch SDNN substitution; use a separately authorized direct WHOOP API source when available.")
        }
        lines.append(IMUNWearableIntelligence.analyze(
            heartRateObservations, primary: primaryWearable).coachingContext)
        return lines.joined(separator: "\n")
    }

    func refresh() {
        guard HKHealthStore.isHealthDataAvailable(), !loading else { return }
        generation += 1
        let activeGeneration = generation
        lastRefreshStartedAt = Date()
        // Keep the last authorized readings visible while the refresh runs.
        // HealthKit results are accumulated outside SwiftUI's render loop.
        loading = true
        status = "Updating authorized Apple Health measurements…"
        let group = DispatchGroup()
        let batch = HCHealthReadBatch()
        for item in catalog {
            guard let type = item.type else { continue }
            group.enter()
            // VO2 max is relatively sparse: keep enough history to compare
            // September with November without extending dense HR sample reads.
            let lookbackDays = item.identifier == "VO2Max" ? 365 : 35
            let predicate = HKQuery.predicateForSamples(
                withStart: Calendar.current.date(byAdding: .day,
                                                  value: -lookbackDays, to: Date()),
                end: Date(), options: .strictStartDate)
            // Bounded query: high-frequency streams can contain very many samples.
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: 2400,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate,
                                                   ascending: false)])
            { [weak self] _, samples, error in
                defer { group.leave() }
                guard error == nil, let items = samples as? [HKQuantitySample],
                      !items.isEmpty else { return }
                // A metric may have multiple publishers; keep data grouped by source.
                let grouped = Dictionary(grouping: items, by: {
                    $0.sourceRevision.source.name
                })
                for (source, readings) in grouped {
                    let perDay = Dictionary(grouping: readings, by: {
                        HCPlanBuilder.dateString($0.endDate)
                    })
                    let points: [HCHealthTrendSample] = perDay.compactMap { date, dayItems in
                        guard !dayItems.isEmpty else { return nil }
                        let values = dayItems.map {
                            $0.quantity.doubleValue(for: item.unit) * item.multiply
                        }.filter { $0.isFinite }.sorted()
                        guard !values.isEmpty else { return nil }
                        let center = values.count / 2
                        let median = values.count.isMultiple(of: 2) ?
                            (values[center - 1] + values[center]) / 2 : values[center]
                        let calculated = item.isDailySum ?
                            values.reduce(0, +) : median
                        return HCHealthTrendSample(name: item.name, source: source,
                                                   date: date, value: calculated)
                    }.sorted { $0.date < $1.date }
                    guard let latest = points.last else { continue }
                    let display: String = {
                        if item.suffix.isEmpty { return String(format: "%.1f", latest.value) }
                        return (abs(latest.value) >= 1000 ?
                            String(format: "%.0f", latest.value) :
                            String(format: "%.1f", latest.value)) + " " + item.suffix
                    }()
                    let metric = HCHealthMetric(
                        name: item.name, value: display, source: source,
                        date: latest.date, category: item.category,
                        unit: item.suffix, numericValue: latest.value,
                        higherIsWorse: item.higherIsWorse,
                        lowerIsWorse: item.lowerIsWorse)
                    batch.append(metric: metric, points: points)
                }
            }
            store.execute(query)
        }
        // Short-interval timestamps are required for cross-device agreement.
        // Daily medians above cannot answer "what did each sensor read now?".
        if let heartType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            group.enter()
            let recent = HKQuery.predicateForSamples(
                withStart: Date().addingTimeInterval(-48 * 3600),
                end: Date(), options: .strictStartDate)
            let recentQuery = HKSampleQuery(
                sampleType: heartType, predicate: recent, limit: 8000,
                sortDescriptors: [NSSortDescriptor(
                    key: HKSampleSortIdentifierEndDate, ascending: false)]) {
                _, results, error in
                defer { group.leave() }
                guard error == nil, let samples = results as? [HKQuantitySample]
                else { return }
                let unit = HKUnit.count().unitDivided(by: .minute())
                batch.appendHeartRates(samples.map { sample in
                    IMUNHeartRateObservation(
                        id: sample.uuid,
                        source: sample.sourceRevision.source.name,
                        bundleID: sample.sourceRevision.source.bundleIdentifier,
                        start: sample.startDate, end: sample.endDate,
                        bpm: sample.quantity.doubleValue(for: unit))
                })
            }
            store.execute(recentQuery)
        }
        group.enter()
        readSleep(group: group, batch: batch)
        group.enter()
        readWorkouts(group: group, batch: batch)
        group.notify(queue: .main) { [weak self] in
            guard let self, self.generation == activeGeneration else { return }
            let result = batch.snapshot()
            self.metrics = result.metrics.sorted {
                if $0.category == $1.category { return $0.name < $1.name }
                return $0.category < $1.category
            }
            self.metricHistory = result.history
            self.heartRateObservations = result.heartRates
            self.loading = false
            self.status = self.metrics.isEmpty ?
                "No readable samples found. Review Health permissions and device sync." :
                "\(self.metrics.count) source-specific measurements loaded."
        }
    }

    private func readSleep(group: DispatchGroup, batch: HCHealthReadBatch) {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            group.leave()
            return
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -35, to: Date()),
            end: Date(), options: .strictStartDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 2500,
                                  sortDescriptors: nil) { [weak self] _, samples, error in
            defer { group.leave() }
            guard error == nil, let items = samples as? [HKCategorySample] else { return }
            let stages: [(Int, String)] = [
                (HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, "Asleep · unspecified"),
                (HKCategoryValueSleepAnalysis.asleepCore.rawValue, "Core sleep"),
                (HKCategoryValueSleepAnalysis.asleepDeep.rawValue, "Deep sleep"),
                (HKCategoryValueSleepAnalysis.asleepREM.rawValue, "REM sleep")
            ]
            for (code, name) in stages + [(-1, "Total asleep")] {
                let actual = code == -1 ?
                    items.filter { sample in stages.contains(where: { $0.0 == sample.value }) } :
                    items.filter { $0.value == code }
                guard !actual.isEmpty else { continue }
                let grouped = Dictionary(grouping: actual, by: { $0.sourceRevision.source.name })
                for (source, bySource) in grouped {
                    // Assign overnight segments to the night they end.
                    let days = Dictionary(grouping: bySource, by: {
                        HCPlanBuilder.dateString($0.endDate)
                    })
                    let points: [HCHealthTrendSample] = days.map { date, entries in
                        // Union overlapping sleep intervals so exports from
                        // one source do not double-count staged and unstaged sleep.
                        let ordered = entries.sorted { $0.startDate < $1.startDate }
                        var seconds = 0.0
                        var coveredUntil = Date.distantPast
                        for segment in ordered {
                            let uncoveredStart = max(segment.startDate, coveredUntil)
                            if segment.endDate > uncoveredStart {
                                seconds += segment.endDate.timeIntervalSince(uncoveredStart)
                            }
                            coveredUntil = max(coveredUntil, segment.endDate)
                        }
                        return HCHealthTrendSample(name: name, source: source,
                                                   date: date, value: seconds / 3600)
                    }.sorted { $0.date < $1.date }
                    guard let latest = points.last else { continue }
                    let metric = HCHealthMetric(name: name,
                        value: String(format: "%.1f h", latest.value),
                        source: source, date: latest.date,
                        category: "Sleep", unit: "h",
                        numericValue: latest.value, lowerIsWorse: code == -1)
                    batch.append(metric: metric, points: points)
                }
            }
        }
        store.execute(query)
    }

    private func readWorkouts(group: DispatchGroup, batch: HCHealthReadBatch) {
        let type = HKObjectType.workoutType()
        let start = Calendar.current.date(byAdding: .day, value: -35, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 500,
                                  sortDescriptors: [NSSortDescriptor(
                                    key: HKSampleSortIdentifierEndDate, ascending: false)])
        { [weak self] _, samples, error in
            defer { group.leave() }
            guard error == nil, let workouts = samples as? [HKWorkout],
                  !workouts.isEmpty else { return }
            let bySource = Dictionary(grouping: workouts, by: {
                $0.sourceRevision.source.name
            })
            for (source, items) in bySource {
                let countPoints = Dictionary(grouping: items, by: {
                    HCPlanBuilder.dateString($0.endDate)
                }).map { date, list in
                    HCHealthTrendSample(name: "Workout sessions", source: source,
                                        date: date, value: Double(list.count))
                }.sorted { $0.date < $1.date }
                guard let latest = countPoints.last else { continue }
                let metric = HCHealthMetric(name: "Workout sessions",
                                            value: String(format: "%.0f",latest.value),
                                            source: source, date: latest.date,
                                            category: "Workouts",unit:"sessions",
                                            numericValue: latest.value)
                batch.append(metric: metric, points: countPoints)
            }
        }
        store.execute(query)
    }
}
