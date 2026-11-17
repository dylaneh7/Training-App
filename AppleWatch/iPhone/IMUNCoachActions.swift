import Foundation
import SwiftUI
import CryptoKit

/// Prescribed workout edits are proposals, not logged performance changes.
enum IMUNCoachExerciseOperation: String, CaseIterable, Identifiable {
    case update, add, replace, remove, moveUp, moveDown
    var id: String { rawValue }
    var title: String {
        switch self {
        case .update: return "Adjust prescription"
        case .add: return "Add exercise"
        case .replace: return "Replace exercise"
        case .remove: return "Remove exercise"
        case .moveUp: return "Move earlier"
        case .moveDown: return "Move later"
        }
    }
}

struct IMUNCoachWorkoutEditHint {
    let operation: IMUNCoachExerciseOperation
    let exerciseName: String?
    let sets: Int?
    let repMin: Int?
    let repMax: Int?
    let restSeconds: Int?
    let weightLb: Double?
}

/// Authorized, version-checked edit to today's prescribed workout.
struct IMUNCoachWorkoutEdit {
    let workoutID: String
    let expectedSignature: String
    let operation: IMUNCoachExerciseOperation
    let exerciseID: String?
    let newName: String?
    let newInstructions: String?
    let sets: Int
    let repMin: Int
    let repMax: Int
    let restSeconds: Int
    let suggestedWeightLb: Double?
}

extension HCWorkout {
    var coachEditSignature: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let payload = try? encoder.encode(self) else { return "" }
        return Data(SHA256.hash(data: payload)).base64EncodedString()
    }
}

/// Narrow, validated app commands. The assistant's narrative never executes
/// directly. Every matching command is reviewed in the iMun Coach UI.
enum IMUNCoachActionKind: Equatable {
    case moveWorkout
    case completeRun
    case completeScheduledWorkout
    case syncWatch
    case setTheme
    case createStrength
    case createRun
    case renameStrength
    case editStrength
    case selectTraining
    case openTab
    case setMotivation
    case setRestDuration
    case setWatchHaptics
    case setRunVoiceCues
    case setRunAutoLaps
}

struct IMUNCoachActionProposal: Identifiable {
    let id = UUID()
    let kind: IMUNCoachActionKind
    let title: String
    let explanation: String
    let suggestedWorkoutID: String?
    let suggestedDate: Date?
    let themeID: String?
    var parameter: String? = nil
    var workoutEdit: IMUNCoachWorkoutEditHint? = nil
}

/// Parses explicit user commands into *proposals*, not side effects. The
/// selected plan, target date, and setting values are checked again on confirm.
enum IMUNCoachActionInterpreter {
    static func propose(_ request: String, sessions: [HCPlannedSession],
                        workout: HCWorkout?, run: HCRunPlan?) -> IMUNCoachActionProposal? {
        let value = request.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let move = containsAny(value, ["move ", "reschedule ", "shift "]) &&
            containsAny(value, ["workout", "session", "run", "lift", "training"])
        if move {
            let sourceDate = matchingDate(value.components(separatedBy: " to ").first ?? value)
            let candidates = sessions.filter { session in
                let titleMatches = value.contains(session.title.lowercased())
                let dateMatches = sourceDate.map {
                    session.date == HCPlanBuilder.dateString($0)
                } ?? false
                return titleMatches || dateMatches
            }
            let matching = candidates.count == 1 ? candidates.first : nil
            let destinationPart = value.components(separatedBy: " to ").dropFirst()
                .joined(separator: " to ")
            return proposal(.moveWorkout, "Move a workout",
                "Select the exact calendar entry and destination date. Finished workouts and recorded sets won't move.",
                workoutID: matching?.id, date: matchingDate(destinationPart))
        }

        if containsAny(value, ["create", "add", "schedule", "make", "plan"]) &&
           containsAny(value, ["run", "running"]) &&
           containsAny(value, ["run", "running"]) &&
           !containsAny(value, ["remind", "recorded"]) {
            return proposal(.createRun, "Create today's running workout",
                "Create a timed run on an empty day, with optional BPM targets. No workout will be marked complete.",
                parameter: suggestedMinutes(value).map { String($0) })
        }

        if containsAny(value, ["create", "add", "make", "plan", "schedule"]) &&
           containsAny(value, ["strength workout", "lifting workout", "weightlifting workout",
                               "custom workout", "weight workout", "new workout"]) {
            return proposal(.createStrength, "Create a strength workout",
                "Create an editable strength session. Exercise sets and weights won't be invented.",
                parameter: namedWorkout(value) ?? "Custom Strength Workout")
        }

        if containsAny(value, ["rename ", "change the name", "call my workout"]) &&
           containsAny(value, ["workout", "lift", "strength"]) && workout != nil {
            return proposal(.renameStrength, "Rename today's strength workout",
                "Change only the workout title. Preserve all prescribed exercises and completed sets.",
                parameter: namedWorkout(value) ?? workout?.title)
        }

        if containsAny(value, ["mark ", "check off ", "complete "]) &&
           containsAny(value, ["workout", "session", "lift", "strength"]) &&
           containsAny(value, ["done", "complete", "finished", "completed"]) {
            let requestedDate = matchingDate(value)
                ?? Calendar.current.startOfDay(for: Date())
            let dateKey = HCPlanBuilder.dateString(requestedDate)
            let available = sessions.filter {
                $0.date == dateKey && !$0.completed &&
                UUID(uuidString: $0.id) != nil
            }
            let exact = available.filter {
                value.contains($0.title.lowercased())
            }
            let selected = exact.count == 1 ? exact.first
                : (available.count == 1 ? available.first : nil)
            return proposal(.completeScheduledWorkout, "Mark calendar workout complete",
                "Confirm the exact saved workout. Only the calendar completion flag is changed; no sets, pace, distance or heart-rate measurements are invented.",
                workoutID: selected?.id)
        }

        if containsAny(value, ["complete", "completed", "finish", "finished",
                                "done", "check off", "mark off"]) &&
           containsAny(value, ["run", "running"]) &&
           containsAny(value, ["mark ", "i ", "my ", "check ", "complete ", "finished"]) {
            guard let run, run.date == HCPlanBuilder.dateString(Date()),
                  !run.isCompleted else { return nil }
            return proposal(.completeRun, "Confirm today's run is complete",
                "Record your confirmation only. Do not fabricate pace, heart rate, distance, or an Apple Health workout.",
                workoutID: run.id)
        }

        if containsAny(value, ["sync ", "send ", "refresh ", "update "]) &&
           containsAny(value, ["watch", "apple watch"]) {
            return proposal(.syncWatch, "Sync today's training to iMun Watch",
                "Refresh the authenticated calendar and use the existing Build 30 phone/cloud delivery.")
        }

        if containsAny(value, ["theme", "appearance", "design", "look"]) &&
           containsAny(value, ["switch", "change", "use", "set", "make"]) {
            let matches = IMUNPreset.allCases.filter { preset in
                value.contains(preset.title.lowercased()) ||
                value.contains(preset.rawValue.lowercased())
            }
            if matches.count == 1, let preset = matches.first {
                return proposal(.setTheme, "Use \(preset.title) theme",
                    "Change only visual styling. No workout records, journal, or motivation content is changed.",
                    theme: preset.rawValue)
            }
        }

        if containsAny(value, ["motivation", "scripture", "bible verse", "motivational"]) &&
           containsAny(value, ["set", "use", "show", "switch", "turn", "change", "enable", "disable"]) {
            let target: String?
            if containsAny(value, ["off", "disable", "no motivation"]) { target = "off" }
            else if containsAny(value, ["scripture", "bible", "verse"]) { target = "scripture" }
            else if value.contains("performance") { target = "performance" }
            else if containsAny(value, ["original", "quotes"]) { target = "original" }
            else if containsAny(value, ["custom", "my own"]) { target = "custom" }
            else { target = nil }
            if let target {
                return proposal(.setMotivation, "Update motivation source",
                    "Use your chosen content source without changing the app's design theme.",
                    parameter: target)
            }
        }

        if containsAny(value, ["rest timer", "rest between sets", "rest duration", "rest period"]) &&
           containsAny(value, ["set", "change", "use", "make", "turn"]) {
            let rest: Int?
            if containsAny(value, ["follow plan", "workout plan", "default"]) { rest = 0 }
            else if value.contains("3 min") || value.contains("180") { rest = 180 }
            else if value.contains("2 min") || value.contains("120") { rest = 120 }
            else if value.contains("90") { rest = 90 }
            else if value.contains("60") || value.contains("1 min") { rest = 60 }
            else { rest = nil }
            if let rest {
                return proposal(.setRestDuration, "Change rest duration",
                    "Set the iMun strength rest timer; no logged sets are modified.",
                    parameter: String(rest))
            }
        }

        if containsAny(value, ["watch haptics", "watch vibration", "haptic feedback"]) &&
           containsAny(value, ["turn", "enable", "disable", "set", "switch"]) {
            return proposal(.setWatchHaptics, "Change Watch haptics",
                "Update iMun Watch's haptic feedback preference.",
                parameter: booleanSetting(value))
        }

        if containsAny(value, ["run voice", "voice cues", "spoken running"]) &&
           containsAny(value, ["turn", "enable", "disable", "set", "switch"]) {
            return proposal(.setRunVoiceCues, "Change running voice cues",
                "Update the in-app running cue preference.",
                parameter: booleanSetting(value))
        }

        if containsAny(value, ["auto laps", "automatic laps"]) &&
           containsAny(value, ["turn", "enable", "disable", "set", "switch"]) {
            return proposal(.setRunAutoLaps, "Change automatic lap cues",
                "Update automatic lap preferences without changing recorded runs.",
                parameter: booleanSetting(value))
        }

        if containsAny(value, ["run tab", "running tab", "switch to running",
                               "show running", "open running", "training to running"]) {
            return proposal(.selectTraining, "Show Running in Training",
                "Switch the Training activity selector to Running.",
                parameter: "run")
        }
        if containsAny(value, ["strength tab", "lifting tab", "switch to strength",
                               "show strength", "open weightlifting"]) {
            return proposal(.selectTraining, "Show Strength in Training",
                "Switch the Training activity selector to Weightlifting.",
                parameter: "weightlifting")
        }

        if containsAny(value, ["open ", "go to ", "show ", "take me to "]) {
            let destinations: [(String, String)] = [
                ("settings", "settings"), ("health", "health"),
                ("recovery", "health"), ("progress", "progress"),
                ("training", "training"), ("coach", "coach")]
            let found = destinations.filter { value.contains($0.0) }
            if found.count == 1, let first = found.first {
                return proposal(.openTab, "Open \(first.1.capitalized)",
                    "Navigate to the requested iMun tab.",
                    parameter: first.1)
            }
        }
        return nil
    }

    /// The local recognizer covers common requests. More conversational
    /// commands can use the existing signed-in Coach service as a classifier,
    /// but ONLY when the athlete clearly asks for an app action.
    static func mightNeedModelProposal(_ request: String) -> Bool {
        let text = request.lowercased()
        return containsAny(text, ["please ", "can you ", "could you ",
            "move", "reschedule", "mark", "schedule", "create", "add ",
            "change", "switch", "set ", "turn ", "open ", "show ",
            "finish", "complete", "adjust", "rename", "update"]) &&
            containsAny(text, ["workout", "run", "strength", "lifting",
                "training", "health", "coach", "theme", "appearance",
                "rest", "watch", "motivation", "haptics", "voice", "laps",
                "calendar", "settings"])
    }

    static func classificationPrompt(for request: String) -> String {
        let content = String(request.prefix(500))
        return """
        Classify the user's iMun app-control request. You are a classifier,
        NOT an executor. Return ONLY a compact JSON object. No markdown.
        Choose "action" from:
        moveWorkout, completeRun, completeScheduledWorkout, syncWatch,
        setTheme, createStrength, createRun, renameStrength, selectTraining,
        openTab, setMotivation, setRestDuration, setWatchHaptics,
        setRunVoiceCues, setRunAutoLaps, none.
        Return {"action":"none"} if the user is asking for advice, information,
        medical interpretation, or something outside those exact capabilities.
        Other optional fields: "parameter" string and "minutes" integer.
        For setting values, use only valid app choices:
        - themes: heritage,retro,techno,coast,fieldNotes,discipline,atelier,rally
        - tabs: training,progress,health,coach,settings
        - activity: run,weightlifting
        - motivation: off,original,performance,scripture,custom
        - haptics/voice/laps: on,off
        - rest seconds: 0,60,90,120,180
        Don't invent session IDs or claim the change is complete.
        User's exact request: \(content)
        """
    }

    /// Strictly validates the model's *suggestion* against the allowlist.
    /// No model-controlled ID, SQL, URL or executable instruction is accepted.
    static func proposalFromModel(_ response: String,
                                  sessions: [HCPlannedSession],
                                  workout: HCWorkout?,
                                  run: HCRunPlan?) -> IMUNCoachActionProposal? {
        guard let open = response.firstIndex(of: "{"),
              let close = response.lastIndex(of: "}"), open <= close else {
            return nil
        }
        let snippet = String(response[open...close])
        guard snippet.utf8.count <= 1500,
              let object = try? JSONSerialization.jsonObject(
                with: Data(snippet.utf8)) as? [String: Any],
              let action = object["action"] as? String else { return nil }
        let value = (object["parameter"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch action {
        case "moveWorkout":
            return proposal(.moveWorkout, "Move a workout",
                "Choose the exact calendar entry and the destination. The AI cannot decide which history records to modify.")
        case "completeScheduledWorkout":
            guard sessions.contains(where: { !$0.completed &&
                UUID(uuidString: $0.id) != nil }) else { return nil }
            return proposal(.completeScheduledWorkout,
                "Confirm a saved workout is complete",
                "Choose the actual calendar session. Recorded sets and activity metrics remain untouched.")
        case "completeRun":
            guard let run, !run.isCompleted,
                  run.date == HCPlanBuilder.dateString(Date()) else { return nil }
            return proposal(.completeRun, "Confirm today's run is complete",
                "This is your confirmation only, not a sensor-recorded activity.",
                workoutID: run.id)
        case "syncWatch":
            return proposal(.syncWatch, "Sync today's Watch plan",
                "Request a fresh authenticated training schedule for iMun Watch.")
        case "createStrength":
            return proposal(.createStrength, "Create a strength workout",
                "Create an empty editable strength plan.",
                parameter: String((value ?? "Custom Strength Workout").prefix(80)))
        case "createRun":
            let minutes = (object["minutes"] as? Int).flatMap {
                (1...360).contains($0) ? $0 : nil
            }
            return proposal(.createRun, "Create today's run",
                "Enter and review the duration and optional BPM goals.",
                parameter: minutes.map { String($0) })
        case "renameStrength":
            guard let workout else { return nil }
            return proposal(.renameStrength, "Rename strength workout",
                "Keep all prescribed exercises and recorded sets intact.",
                parameter: String((value ?? workout.title).prefix(80)))
        case "setTheme":
            guard let value, let preset = IMUNPreset(rawValue: value) else { return nil }
            return proposal(.setTheme, "Use \(preset.title) theme",
                "Only visual design changes.", theme: preset.rawValue)
        case "setMotivation":
            guard let value, ["off", "original", "performance",
                              "scripture", "custom"].contains(value) else { return nil }
            return proposal(.setMotivation, "Update motivation",
                "Change the daily content source independently of design.",
                parameter: value)
        case "setRestDuration":
            guard let value, let seconds = Int(value),
                  [0,60,90,120,180].contains(seconds) else { return nil }
            return proposal(.setRestDuration, "Update rest timer",
                "Change the workout rest countdown without editing records.",
                parameter: String(seconds))
        case "setWatchHaptics", "setRunVoiceCues", "setRunAutoLaps":
            guard value == "on" || value == "off" else { return nil }
            let kind: IMUNCoachActionKind = action == "setWatchHaptics"
                ? .setWatchHaptics
                : (action == "setRunVoiceCues" ? .setRunVoiceCues : .setRunAutoLaps)
            return proposal(kind, "Update training feedback",
                "Change the selected app preference.", parameter: value)
        case "selectTraining":
            guard value == "run" || value == "weightlifting" else { return nil }
            return proposal(.selectTraining, "Switch Training activity",
                "Show the selected activity in Training.", parameter: value)
        case "openTab":
            guard let value, ["training","progress","health","coach","settings"]
                .contains(value) else { return nil }
            return proposal(.openTab, "Open \(value.capitalized)",
                "Navigate to that app section.", parameter: value)
        default:
            return nil
        }
    }

    private static func containsAny(_ input: String, _ terms: [String]) -> Bool {
        terms.contains { input.contains($0) }
    }

    private static func proposal(_ kind: IMUNCoachActionKind,
                                 _ title: String, _ explanation: String,
                                 workoutID: String? = nil, date: Date? = nil,
                                 theme: String? = nil,
                                 parameter: String? = nil) -> IMUNCoachActionProposal {
        IMUNCoachActionProposal(kind: kind, title: title, explanation: explanation,
                                suggestedWorkoutID: workoutID,
                                suggestedDate: date, themeID: theme,
                                parameter: parameter)
    }

    private static func namedWorkout(_ input: String) -> String? {
        for delimiter in [" called ", " named ", " to "] {
            if let range = input.range(of: delimiter) {
                let name = input[range.upperBound...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return String(name.prefix(80)) }
            }
        }
        return nil
    }

    private static func booleanSetting(_ value: String) -> String? {
        if containsAny(value, ["off", "disable", "stop"]) { return "off" }
        if containsAny(value, ["on", "enable", "start"]) { return "on" }
        return nil
    }

    private static func suggestedMinutes(_ value: String) -> Int? {
        let pattern = #"\b(\d{1,3})\s*[- ]?\s*(?:minutes?|mins?)\b"#
        guard let match = value.range(of: pattern, options: .regularExpression)
        else { return nil }
        let numbers = String(value[match]).prefix(while: { $0.isNumber })
        guard let n = Int(numbers), (1...360).contains(n) else { return nil }
        return n
    }

    private static func matchingDate(_ request: String) -> Date? {
        let text = request.lowercased()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        if let range = text.range(of: #"\b20\d\d-\d\d-\d\d\b"#,
                                  options: .regularExpression) {
            return HCPlanBuilder.startOfDate(String(text[range]))
        }
        if text.contains("tomorrow") { return calendar.date(byAdding: .day, value: 1, to: start) }
        if text.contains("today") { return start }
        let weekdays = ["sunday", "monday", "tuesday", "wednesday",
                        "thursday", "friday", "saturday"]
        for (index, day) in weekdays.enumerated() where text.contains(day) {
            let current = calendar.component(.weekday, from: start)
            let delta = ((index + 1) - current + 7) % 7
            let days = text.contains("next \(day)") && delta == 0 ? 7 : delta
            return calendar.date(byAdding: .day, value: days, to: start)
        }
        return nil
    }
}


/// Dedicated review UI keeps the conversation lightweight and gives every
/// persistent app change the same approval/cancel controls.
struct IMUNCoachActionReviewCard: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge

    let action: IMUNCoachActionProposal
    @Binding var selectedWorkoutID: String
    @Binding var moveDate: Date
    @Binding var workoutTitle: String
    @Binding var runMinutes: Int
    @Binding var runHasHR: Bool
    @Binding var runMinBPM: Int
    @Binding var runMaxBPM: Int
    let canConfirm: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HCCard(accent: HCDesign.electric) {
            VStack(alignment: .leading, spacing: 12) {
                Label("REVIEW APP CHANGE", systemImage: "checkmark.shield")
                    .font(HCDesign.label(11))
                    .foregroundStyle(HCDesign.electric)
                Text(action.title)
                    .font(HCDesign.display(20))
                    .foregroundStyle(HCDesign.ink)
                Text(action.explanation)
                    .font(.caption)
                    .foregroundStyle(HCDesign.secondary)

                if action.kind == .moveWorkout {
                    Picker("Workout to move", selection: $selectedWorkoutID) {
                        Text("Choose a workout").tag("")
                        ForEach(coach.plannedSessions) { entry in
                            Text("\(entry.date) · \(entry.title)")
                                .tag(entry.id)
                        }
                    }
                    .tint(HCDesign.aqua)
                    DatePicker("Move to", selection: $moveDate,
                               displayedComponents: .date)
                        .tint(HCDesign.aqua)
                }
                if action.kind == .completeScheduledWorkout {
                    Picker("Calendar workout", selection: $selectedWorkoutID) {
                        Text("Choose an unfinished workout").tag("")
                        ForEach(coach.plannedSessions.filter {
                            !$0.completed && UUID(uuidString: $0.id) != nil
                        }) { entry in
                            Text("\(entry.date) · \(entry.title)")
                                .tag(entry.id)
                        }
                    }
                    .tint(HCDesign.aqua)
                }
                if action.kind == .createStrength ||
                   action.kind == .renameStrength {
                    TextField("Workout name", text: $workoutTitle)
                        .textInputAutocapitalization(.words)
                }
                if action.kind == .createRun {
                    TextField("Run name", text: $workoutTitle)
                        .textInputAutocapitalization(.words)
                    Stepper("Duration: \(runMinutes) minutes",
                            value: $runMinutes, in: 1...360)
                    Toggle("Add target BPM range", isOn: $runHasHR)
                    if runHasHR {
                        HStack {
                            TextField("Minimum BPM", value: $runMinBPM, format: .number)
                                .keyboardType(.numberPad)
                            Text("to")
                            TextField("Maximum BPM", value: $runMaxBPM, format: .number)
                                .keyboardType(.numberPad)
                        }
                    }
                }
                if let parameter = action.parameter,
                   action.kind != .createRun &&
                   action.kind != .createStrength &&
                   action.kind != .renameStrength {
                    Text("Selected value: \(parameter)")
                        .font(.caption2)
                        .foregroundStyle(HCDesign.secondary)
                }
                HStack(spacing: 10) {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                        .tint(HCDesign.secondary)
                    Button("Confirm action", action: onConfirm)
                        .buttonStyle(.borderedProminent)
                        .tint(HCDesign.electric)
                        .disabled(!canConfirm)
                }
                Text("Generated Coach text cannot perform an app change without confirmation.")
                    .font(.caption2)
                    .foregroundStyle(HCDesign.secondary)
            }
        }
    }
}
