import Foundation
import SwiftUI
import HealthKit
import WorkoutKit

// Structured runs belong to the existing Command Center run, not the strength
// workout. This draft is kept on-device until the planner exposes typed steps.
private enum IMUNRunPhase: String, Codable, CaseIterable, Identifiable {
    case warmup, work, recovery, cooldown
    var id: String { rawValue }
    var title: String {
        switch self {
        case .warmup: return "Warm-up"
        case .work: return "Run"
        case .recovery: return "Recovery"
        case .cooldown: return "Cooldown"
        }
    }
}

private enum IMUNRunGoal: String, Codable, CaseIterable, Identifiable {
    case minutes, miles, open
    var id: String { rawValue }
    var title: String {
        switch self {
        case .minutes: return "Time (min)"
        case .miles: return "Distance (mi)"
        case .open: return "Open"
        }
    }
}

private struct IMUNRunSegment: Codable, Identifiable, Equatable {
    var id = UUID()
    var phase: IMUNRunPhase
    var label: String
    var goal: IMUNRunGoal = .minutes
    var amount: Double = 5
    var hasHeartRate = false
    var minBPM = 0
    var maxBPM = 0

    static func new(_ phase: IMUNRunPhase) -> Self {
        .init(phase: phase, label: phase.title)
    }
}

private struct IMUNRunDraft: Codable, Equatable {
    var workoutUUID = UUID()
    var plannerID: String
    var date: String
    var outdoor = true
    var segments: [IMUNRunSegment]

    static func initial(for plan: HCRunPlan) -> Self {
        // Don't invent Garmin intervals from free-form calendar notes.
        // Preserve the distance prescribed by the existing planner when known.
        var base = IMUNRunSegment.new(.work)
        if let miles = plan.targetDistanceMiles, miles > 0 {
            base.goal = .miles
            base.amount = miles
        } else {
            base.goal = .open
        }
        return .init(plannerID: plan.id, date: plan.date, segments: [base])
    }
}

private enum IMUNRunDraftStore {
    private static func key(_ planID: String, _ date: String) -> String {
        "imun.apple-workout.run.\(planID).\(date)"
    }

    static func load(_ plan: HCRunPlan) -> IMUNRunDraft {
        let saved = UserDefaults.standard.data(forKey: key(plan.id, plan.date))
        if let saved,
           let draft = try? JSONDecoder().decode(IMUNRunDraft.self, from: saved),
           draft.plannerID == plan.id, draft.date == plan.date {
            return draft
        }
        return .initial(for: plan)
    }

    static func save(_ draft: IMUNRunDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: key(draft.plannerID, draft.date))
    }
}

private enum IMUNRunSchedulingError: LocalizedError {
    case unavailable, permission, invalid(String), unconfirmed, limit
    var errorDescription: String? {
        switch self {
        case .unavailable: return "This iPhone cannot schedule workouts in Apple Workout."
        case .permission: return "Allow iMun to schedule workouts in Apple Workout when prompted."
        case .invalid(let detail): return detail
        case .unconfirmed: return "Apple did not confirm the scheduled workout. Check the Watch and retry."
        case .limit: return "Apple Workout's scheduled-workout limit has been reached."
        }
    }
}

@MainActor
private enum IMUNAppleRunningScheduler {
    static func send(_ draft: IMUNRunDraft, title: String) async throws {
        guard WorkoutScheduler.isSupported else {
            throw IMUNRunSchedulingError.unavailable
        }
        guard !draft.segments.isEmpty,
              draft.segments.contains(where: { $0.phase == .work }) else {
            throw IMUNRunSchedulingError.invalid("Add at least one Run interval.")
        }
        for (index, segment) in draft.segments.enumerated() {
            if segment.phase == .warmup && index != 0 {
                throw IMUNRunSchedulingError.invalid("Warm-up must be first.")
            }
            if segment.phase == .cooldown && index != draft.segments.count - 1 {
                throw IMUNRunSchedulingError.invalid("Cooldown must be last.")
            }
        }
        guard let parts = parseDate(draft.date) else {
            throw IMUNRunSchedulingError.invalid("The scheduled run has an invalid date.")
        }
        let location: HKWorkoutSessionLocationType = draft.outdoor ? .outdoor : .indoor
        var warmup: WorkoutStep?
        var cooldown: WorkoutStep?
        var intervals: [IntervalStep] = []
        for segment in draft.segments {
            let step = try makeStep(segment, location: location)
            switch segment.phase {
            case .warmup: warmup = step
            case .cooldown: cooldown = step
            case .work: intervals.append(IntervalStep(.work, step: step))
            case .recovery: intervals.append(IntervalStep(.recovery, step: step))
            }
        }
        guard !intervals.isEmpty else {
            throw IMUNRunSchedulingError.invalid("Add at least one Run interval.")
        }
        let custom = CustomWorkout(
            activity: .running, location: location, displayName: title,
            warmup: warmup,
            // Flatten steps so the last repetition doesn't gain an extra recovery.
            blocks: [IntervalBlock(steps: intervals, iterations: 1)],
            cooldown: cooldown)
        let plan = WorkoutPlan(.custom(custom), id: draft.workoutUUID)
        let scheduler = WorkoutScheduler.shared
        let existingAuthorization = await scheduler.authorizationState
        let authorization = existingAuthorization == .notDetermined
            ? await scheduler.requestAuthorization() : existingAuthorization
        guard authorization == .authorized else {
            throw IMUNRunSchedulingError.permission
        }

        // Replacing the same planned run must not stack copies on the watch.
        let previous = await scheduler.scheduledWorkouts
        let old = previous.filter { $0.plan.id == draft.workoutUUID }
        if previous.count - old.count >= WorkoutScheduler.maxAllowedScheduledWorkoutCount {
            throw IMUNRunSchedulingError.limit
        }
        for item in old {
            await scheduler.remove(item.plan, at: item.date)
        }
        await scheduler.schedule(plan, at: parts)
        let confirmed = await scheduler.scheduledWorkouts
        guard confirmed.contains(where: { $0.plan.id == draft.workoutUUID &&
            $0.date.year == parts.year && $0.date.month == parts.month &&
            $0.date.day == parts.day }) else {
            throw IMUNRunSchedulingError.unconfirmed
        }
        // Scheduling is not completion. The existing HealthKit run importer
        // handles actual results, and the bridge deduplicates completed runs.
    }

    private static func parseDate(_ value: String) -> DateComponents? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]),
              (1...31).contains(parts[2]) else { return nil }
        return DateComponents(year: parts[0], month: parts[1], day: parts[2])
    }

    private static func makeStep(_ segment: IMUNRunSegment,
                                 location: HKWorkoutSessionLocationType) throws -> WorkoutStep {
        let goal: WorkoutGoal
        switch segment.goal {
        case .minutes:
            guard segment.amount.isFinite && segment.amount > 0 else {
                throw IMUNRunSchedulingError.invalid("Enter a positive number of minutes for \(segment.label).")
            }
            goal = .time(segment.amount * 60, .seconds)
        case .miles:
            guard segment.amount.isFinite && segment.amount > 0 else {
                throw IMUNRunSchedulingError.invalid("Enter a positive distance for \(segment.label).")
            }
            goal = .distance(segment.amount * 1609.344, .meters)
        case .open:
            goal = .open
        }
        guard CustomWorkout.supportsGoal(goal, activity: .running, location: location) else {
            throw IMUNRunSchedulingError.invalid("Apple Workout doesn't support this interval goal.")
        }
        var alert: (any WorkoutAlert)?
        if segment.hasHeartRate {
            guard (30...240).contains(segment.minBPM),
                  (30...240).contains(segment.maxBPM),
                  segment.minBPM <= segment.maxBPM else {
                throw IMUNRunSchedulingError.invalid("Enter a valid minimum and maximum BPM for \(segment.label).")
            }
            let candidate = HeartRateRangeAlert.heartRate(
                Double(segment.minBPM)...Double(segment.maxBPM),
                unit: WorkoutAlertMetric.countPerMinute)
            guard CustomWorkout.supportsAlert(candidate, activity: .running,
                                               location: location) else {
                throw IMUNRunSchedulingError.invalid("This heart-rate alert isn't supported for that run.")
            }
            alert = candidate
        }
        var step = WorkoutStep(goal: goal, alert: alert)
        if #available(iOS 18.0, *) {
            let name = segment.label.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { step.displayName = name }
        }
        return step
    }
}

/// Editor launched from the real Training > Running card. The current backend
/// supplies title, notes and distance, but not machine-readable interval steps.
struct IMUNStructuredRunEditor: View {
    let plan: HCRunPlan
    @Environment(\.dismiss) private var dismiss
    @State private var draft: IMUNRunDraft
    @State private var isSending = false
    @State private var message: String?

    init(plan: HCRunPlan) {
        self.plan = plan
        _draft = State(initialValue: IMUNRunDraftStore.load(plan))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("From your training plan") {
                    Text(plan.title).font(.headline)
                    Text(plan.date).font(.caption).foregroundStyle(.secondary)
                    if !plan.notes.isEmpty {
                        Text(plan.notes).font(.subheadline)
                    }
                    if let miles = plan.targetDistanceMiles {
                        LabeledContent("Planned distance",
                                       value: String(format: "%.2f mi", miles))
                    }
                    Text("Check each step against your coach's instructions. Free-text notes aren't converted into guessed intervals.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Apple Watch workout") {
                    Toggle("Outdoor run", isOn: $draft.outdoor)
                    Text("Intervals, time or distance goals, and exact BPM alerts are sent to Apple's Workout app.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Workout steps — in order") {
                    ForEach($draft.segments) { $segment in
                        IMUNRunSegmentEditor(segment: $segment) {
                            draft.segments.removeAll { $0.id == segment.id }
                        }
                    }
                    Button("Add warm-up") {
                        if !draft.segments.contains(where: { $0.phase == .warmup }) {
                            draft.segments.insert(.new(.warmup), at: 0)
                        }
                    }
                    Button("Add run interval") { insertBeforeCooldown(.new(.work)) }
                    Button("Add recovery interval") { insertBeforeCooldown(.new(.recovery)) }
                    Button("Add cooldown") {
                        if !draft.segments.contains(where: { $0.phase == .cooldown }) {
                            draft.segments.append(.new(.cooldown))
                        }
                    }
                }
                Section {
                    Button {
                        IMUNRunDraftStore.save(draft)
                        isSending = true
                        message = nil
                        Task {
                            do {
                                try await IMUNAppleRunningScheduler.send(draft, title: plan.title)
                                message = "Scheduled in Apple Workout for \(plan.date). Check the Workout app on Apple Watch."
                            } catch {
                                message = error.localizedDescription
                            }
                            isSending = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "applewatch")
                            Text(isSending ? "Scheduling…" : "Send structured run to Apple Watch")
                        }
                    }
                    .disabled(isSending)
                    if let message {
                        Text(message).font(.subheadline)
                    }
                    Text("This schedules the run; it does not mark it completed. Finished workouts still return through Apple Health.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Structured Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: draft) { _, value in IMUNRunDraftStore.save(value) }
        }
    }

    private func insertBeforeCooldown(_ segment: IMUNRunSegment) {
        if let last = draft.segments.last, last.phase == .cooldown {
            draft.segments.insert(segment, at: draft.segments.count - 1)
        } else {
            draft.segments.append(segment)
        }
    }
}

private struct IMUNRunSegmentEditor: View {
    @Binding var segment: IMUNRunSegment
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Step", selection: $segment.phase) {
                ForEach(IMUNRunPhase.allCases) { phase in
                    Text(phase.title).tag(phase)
                }
            }
            TextField("Interval name", text: $segment.label)
                .textInputAutocapitalization(.words)
            Picker("Goal", selection: $segment.goal) {
                ForEach(IMUNRunGoal.allCases) { goal in
                    Text(goal.title).tag(goal)
                }
            }
            if segment.goal != .open {
                HStack {
                    Text(segment.goal == .minutes ? "Minutes" : "Miles")
                    Spacer()
                    TextField("Amount", value: $segment.amount, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
            }
            Toggle("Target heart-rate range", isOn: $segment.hasHeartRate)
            if segment.hasHeartRate {
                HStack {
                    TextField("Min BPM", value: $segment.minBPM, format: .number)
                        .keyboardType(.numberPad)
                    Text("–")
                    TextField("Max BPM", value: $segment.maxBPM, format: .number)
                        .keyboardType(.numberPad)
                    Text("bpm").foregroundStyle(.secondary)
                }
            }
            Button("Remove step", role: .destructive, action: onRemove)
                .font(.caption)
        }
        .padding(.vertical, 6)
    }
}
