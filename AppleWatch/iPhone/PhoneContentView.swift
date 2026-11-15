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
                .tabItem { Label("Coach", systemImage: "bubble.left.and.text.bubble.right") }
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
                                    Text("\(exercise.prescribedSets) sets × \(exercise.repDescription)")
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
                Section {
                    Text("Hold and drag in Edit mode to reorder. Swipe left to remove. Tap an exercise to edit its sets, suggested load, reps, directions, or swap it.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Section("No Strength Workout Scheduled") {
                    Text("You can create a session on any date without changing your regular split.")
                        .foregroundStyle(.secondary)
                    Button("Create Workout") { showNewSession = true }
                        .buttonStyle(.borderedProminent)
                }
            }

            if coach.savingPlan || coach.cloudPendingCount > 0 {
                Section("Sync") {
                    if coach.savingPlan { ProgressView("Saving changes…") }
                    Text("\(coach.cloudPendingCount) sets/runs waiting for cloud upload")
                        .font(.caption)
                    Button("Retry Uploads") {
                        coach.retryPendingWorkout()
                        coach.retryPendingCloudSets()
                    }
                }
            }
            Section { Text(coach.status).font(.footnote).foregroundStyle(.secondary) }
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
                    exerciseIndex:index,prescribedSets:3,repMin:8,repMax:12,
                    suggestedWeightLb:nil,restSeconds:120
                )
                let suggestion = coach.suggestion(for:draft,on:plan.date,aggressive:aggressive)
                var added = HCExercise(
                    id:draft.id,name:item.name,originalName:item.name,
                    exerciseIndex:index,prescribedSets:3,repMin:8,repMax:12,
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
    @State private var showSwap = false
    @State private var editingSet: HCLoggedSet?

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
                    Stepper("Working sets: \(sets)",value:$sets,in:1...12)
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
                                weightLb:Double(newWeight),reps:newReps,rir:Double(newRIR))
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Cancel Set",role:.destructive) { coach.cancelPhoneSet() }
                    } else {
                        Text("Finish your current set in the other exercise first.")
                            .font(.caption)
                    }
                    Button("Log Set Without Timer") {
                        coach.logFromPhone(exercise:exercise,
                            weightLb:Double(newWeight),reps:newReps,rir:Double(newRIR))
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
                                Text("Set \(set.index)")
                                Spacer()
                                Text("\(set.weightLb.map{$0.formatted()+" lb"} ?? "Unrecorded") × \(set.reps)")
                                Image(systemName:"pencil")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercise")
        .sheet(isPresented:$showSwap) {
            ExerciseLibraryPicker { item in swapTo(item) }
        }
        .sheet(item:$editingSet) { set in
            SetCorrectionSheet(entry:set)
                .environmentObject(coach)
        }
        .onAppear { loadFromExercise() }
    }

    private func loadFromExercise() {
        guard let e = exercise else { return }
        sets=e.prescribedSets;minimum=e.repMin;maximum=e.repMax
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

struct ExerciseLibraryPicker: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (HCLibraryExercise) -> Void
    @State private var search = ""
    @State private var category = "All"
    @State private var showingCustom = false
    @State private var customName = ""
    @State private var customInstructions = ""
    @State private var customGroup = "Other"

    private var results: [HCLibraryExercise] {
        HCExerciseLibrary.all.filter { e in
            (category == "All" || e.group == category) &&
            (search.isEmpty || e.name.localizedCaseInsensitiveContains(search) ||
                e.equipment.localizedCaseInsensitiveContains(search) ||
                e.group.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Muscle group",selection:$category) {
                    ForEach(["All","Chest","Back","Shoulders","Arms","Legs","Traps","Core"],id:\.self) { Text($0) }
                }
                Button {
                    showingCustom = true
                } label: {
                    Label("Create Custom Exercise",systemImage:"plus")
                }
                ForEach(results) { item in
                    VStack(alignment:.leading,spacing:7) {
                        HStack {
                            Text(item.name).font(.headline)
                            Spacer()
                            Button("Select") {
                                onSelect(item)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                        Text("\(item.group) · \(item.equipment)")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(item.instructions).font(.footnote)
                    }
                    .padding(.vertical,3)
                }
            }
            .searchable(text:$search,prompt:"Search 50 exercises")
            .navigationTitle("Exercise Library")
            .sheet(isPresented:$showingCustom) {
                NavigationStack {
                    Form {
                        TextField("Exercise name",text:$customName)
                        TextField("Muscle group",text:$customGroup)
                        Section("How to perform it") {
                            TextEditor(text:$customInstructions).frame(minHeight:130)
                        }
                    }
                    .navigationTitle("New Exercise")
                    .toolbar {
                        ToolbarItem(placement:.cancellationAction) {
                            Button("Cancel") {showingCustom=false}
                        }
                        ToolbarItem(placement:.confirmationAction) {
                            Button("Add") {
                                let name=customName.trimmingCharacters(in:.whitespacesAndNewlines)
                                guard !name.isEmpty else{return}
                                onSelect(HCLibraryExercise(
                                    name:name,group:customGroup,
                                    equipment:"Custom",instructions:customInstructions))
                                showingCustom=false
                                dismiss()
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement:.cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct RunHome: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Binding var date: Date

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
                Button("Send Today's Run to Apple Watch") {
                    coach.sendToWatch()
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
            Section("Development") {
                Text("Changes requested in ChatGPT can be committed to your GitHub project. To install native updates, rebuild through Xcode or a future TestFlight release.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Health Coach Native — iPhone and Apple Watch")
                    .font(.caption)
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

final class HCAppleHealthReader: ObservableObject {
    @Published private(set) var metrics: [HCHealthMetric] = []
    @Published private(set) var metricHistory: [HCHealthTrendSample] = []
    @Published private(set) var status =
        "Connect Apple Health to view available measurements, trends, and sources."
    @Published private(set) var loading = false
    private let store = HKHealthStore()
    private var generation = 0

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

    func connect() {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "Apple Health isn't available on this device."
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
        store.requestAuthorization(toShare: [], read: types) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.status = error.localizedDescription
                    return
                }
                UserDefaults.standard.set(true, forKey: "hcHealthCatalogEnabled")
                self.refresh()
            }
        }
    }

    func refreshIfAuthorized() {
        if UserDefaults.standard.bool(forKey: "hcHealthCatalogEnabled") {
            refresh()
        }
    }

    func refresh() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        generation += 1
        let activeGeneration = generation
        metrics = []
        metricHistory = []
        loading = true
        status = "Reading authorized data from Apple Health…"
        let group = DispatchGroup()
        for item in catalog {
            guard let type = item.type else { continue }
            group.enter()
            let predicate = HKQuery.predicateForSamples(
                withStart: Calendar.current.date(byAdding: .day, value: -35, to: Date()),
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
                    DispatchQueue.main.async {
                        guard self?.generation == activeGeneration else { return }
                        self?.metrics.append(metric)
                        self?.metricHistory.append(contentsOf: points)
                    }
                }
            }
            store.execute(query)
        }
        group.enter()
        readSleep(group: group, generation: activeGeneration)
        group.enter()
        readWorkouts(group: group, generation: activeGeneration)
        group.notify(queue: .main) { [weak self] in
            guard let self, self.generation == activeGeneration else { return }
            self.loading = false
            self.metrics.sort {
                if $0.category == $1.category { return $0.name < $1.name }
                return $0.category < $1.category
            }
            self.status = self.metrics.isEmpty ?
                "No readable samples found. Review Health permissions and device sync." :
                "\(self.metrics.count) source-specific measurements loaded."
        }
    }

    private func readSleep(group: DispatchGroup, generation: Int) {
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
                        let seconds = entries.reduce(0.0) {
                            $0 + $1.endDate.timeIntervalSince($1.startDate)
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
                    DispatchQueue.main.async {
                        guard self?.generation == generation else { return }
                        self?.metrics.append(metric)
                        self?.metricHistory.append(contentsOf: points)
                    }
                }
            }
        }
        store.execute(query)
    }

    private func readWorkouts(group: DispatchGroup, generation: Int) {
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
                DispatchQueue.main.async {
                    guard self?.generation == generation else { return }
                    self?.metrics.append(metric)
                    self?.metricHistory.append(contentsOf: countPoints)
                }
            }
        }
        store.execute(query)
    }
}
