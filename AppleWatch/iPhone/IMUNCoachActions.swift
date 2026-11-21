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
    var newName: String? = nil
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
enum IMUNCoachActionKind: String, CaseIterable {
    case moveWorkout
    case completeRun
    case completeScheduledWorkout
    case syncWatch
    case setTheme
    case createStrength
    case createRun
    case renameStrength
    case editStrength
    case undoSet
    case undoWorkout
    case selectTraining
    case openTab
    case setMotivation
    case setRestDuration
    case setWatchHaptics
    case setRunVoiceCues
    case setRunAutoLaps
    case setAppPreference
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
    var settingKey: String? = nil
}

/// Explicitly editable app preferences. No arbitrary UserDefaults keys,
/// account secrets or health-sharing flags can be reached through this path.
struct IMUNCoachPreference: Identifiable {
    enum ValueType { case bool, string, integer, decimal }
    let id: String
    let title: String
    let choices: [String]
    let type: ValueType
    let category: String

    static let all: [IMUNCoachPreference] = [
        .init(id: "hcDesignReduceMotion", title: "Reduce animation",
              choices: ["on", "off"], type: .bool, category: "Appearance"),
        .init(id: "hcMotivationTone", title: "Motivation tone",
              choices: ["quiet", "direct", "rigorous"], type: .string,
              category: "Motivation"),
        .init(id: "hcMotivationTranslation", title: "Scripture reference translation",
              choices: ["ESV", "LSB"], type: .string, category: "Motivation"),
        .init(id: "hcMotivationShowTraining", title: "Show motivation in Training",
              choices: ["on", "off"], type: .bool, category: "Motivation"),
        .init(id: "hcAggressiveProgression", title: "Aggressive strength progression",
              choices: ["on", "off"], type: .bool, category: "Training"),
        .init(id: "hcWeightIncrement", title: "Weight adjustment increment",
              choices: ["2.5", "5", "10"], type: .decimal, category: "Training"),
        .init(id: "hcRunCueMinutes", title: "Running cue interval",
              choices: ["1", "3", "5", "10", "15"], type: .integer,
              category: "Running"),
        .init(id: "hcRunIntervals", title: "Show running intervals",
              choices: ["on", "off"], type: .bool, category: "Running")
    ]

    static func byID(_ id: String) -> IMUNCoachPreference? {
        all.first(where: { $0.id == id })
    }

    /// Returns a verified local result or nil; no unrestricted dictionary
    /// manipulation, sensitive permissions or implicit server access.
    @discardableResult
    static func apply(id: String, value: String) -> String? {
        guard let setting = byID(id), setting.choices.contains(value) else {
            return nil
        }
        let prefs = UserDefaults.standard
        switch setting.type {
        case .bool:
            prefs.set(value == "on", forKey: id)
        case .string:
            prefs.set(value, forKey: id)
        case .integer:
            guard let number = Int(value) else { return nil }
            prefs.set(number, forKey: id)
        case .decimal:
            guard let number = Double(value), number.isFinite else { return nil }
            prefs.set(number, forKey: id)
        }
        return setting.title + " changed to " + value + "."
    }
}

/// One source of truth for which app operations Coach can offer.
/// Adding a capability means wiring a validated proposal and native action,
/// not granting the language model access to arbitrary internal objects.
struct IMUNCoachActionDescriptor: Identifiable {
    let kind: IMUNCoachActionKind
    let domain: String
    let title: String
    let summary: String
    let access: String
    var id: String { kind.rawValue }
}

enum IMUNCoachActionCatalog {
    static let available: [IMUNCoachActionDescriptor] = [
        .init(kind: .editStrength, domain: "Training", title: "Edit exercises",
              summary: "Add, replace, remove, reorder and change sets, reps, rest or suggested load.",
              access: "Review and confirm"),
        .init(kind: .undoSet, domain: "Training", title: "Undo Set",
              summary: "Reverse a recorded set while preserving other progress.",
              access: "Review and confirm"),
        .init(kind: .undoWorkout, domain: "Training", title: "Undo Workout",
              summary: "Reverse an active iPhone workout and its sets; keep the plan.",
              access: "Review and confirm"),
        .init(kind: .createStrength, domain: "Training", title: "Create strength workout",
              summary: "Create a blank workout for today.", access: "Review and confirm"),
        .init(kind: .renameStrength, domain: "Training", title: "Rename a workout",
              summary: "Rename today's prescribed strength workout.", access: "Review and confirm"),
        .init(kind: .createRun, domain: "Training", title: "Create a run",
              summary: "Create a timed running plan with optional heart-rate targets.", access: "Review and confirm"),
        .init(kind: .moveWorkout, domain: "Calendar", title: "Reschedule a session",
              summary: "Move a real planner session after choosing its date.", access: "Review and confirm"),
        .init(kind: .completeScheduledWorkout, domain: "Calendar", title: "Mark a workout done",
              summary: "Confirm a saved scheduled workout is complete, without invented metrics.", access: "Review and confirm"),
        .init(kind: .completeRun, domain: "Running", title: "Confirm completed run",
              summary: "Confirm today's run without inserting sensor values.", access: "Review and confirm"),
        .init(kind: .syncWatch, domain: "Watch", title: "Sync the Watch",
              summary: "Refresh the existing signed-in cloud and Watch workout schedule.", access: "Review and confirm"),
        .init(kind: .setMotivation, domain: "Motivation", title: "Change motivation",
              summary: "Select Scripture, original, performance, custom or off.", access: "Review and confirm"),
        .init(kind: .setRestDuration, domain: "Training", title: "Change rest timer",
              summary: "Adjust planned strength rest preference.", access: "Review and confirm"),
        .init(kind: .setWatchHaptics, domain: "Watch", title: "Watch haptics",
              summary: "Enable or disable workout vibration preference.", access: "Review and confirm"),
        .init(kind: .setRunVoiceCues, domain: "Running", title: "Running voice cues",
              summary: "Enable or disable speech cues.", access: "Review and confirm"),
        .init(kind: .setRunAutoLaps, domain: "Running", title: "Automatic laps",
              summary: "Enable or disable automatic lap cues.", access: "Review and confirm"),
        .init(kind: .setAppPreference, domain: "Settings", title: "Adjust app preferences",
              summary: "Set supported accessibility, motivation, progression and running preferences.",
              access: "Review and confirm"),
        .init(kind: .selectTraining, domain: "Navigation", title: "Change sport",
              summary: "Switch between Strength and Running.", access: "Review and confirm"),
        .init(kind: .openTab, domain: "Navigation", title: "Navigate app",
              summary: "Open Training, Progress, Health, Coach or Settings.", access: "Review and confirm")
    ]

    static let viewOnly: [(area: String, scope: String)] = [
        ("Health measurements", "Inspect authorized records and source-specific trends; no invented data or unsupported HealthKit edits"),
        ("Recorded workout history", "Inspect source recordings; corrections must use a separate authenticated record-specific operation"),
        ("Accounts and permissions", "Navigate to settings; system permissions and sign-in require the user"),
        ("External workout providers", "Read or export only through approved provider integrations")
    ]

    static var modelAllowlist: String {
        available.map { "\($0.kind.rawValue): \($0.summary)" }.joined(separator: "\n")
    }

    static var userFacingSummary: String {
        let groups = Dictionary(grouping: available, by: \.domain)
        let domains = groups.keys.sorted().map { domain in
            domain + ": " + (groups[domain] ?? []).map(\.title).joined(separator: ", ")
        }
        return "I can prepare app changes across iMun. Every edit is shown for your approval.\n" +
            domains.joined(separator: "\n") +
            "\nHealth records and permissions stay source-controlled. " +
            "If an operation isn't yet connected, I'll explain the limitation rather than claiming I changed it."
    }
}

/// Parses explicit user commands into *proposals*, not side effects. The
/// selected plan, target date, and setting values are checked again on confirm.
enum IMUNCoachActionInterpreter {
    static func propose(_ request: String, sessions: [HCPlannedSession],
                        workout: HCWorkout?, run: HCRunPlan?) -> IMUNCoachActionProposal? {
        let value = request.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if containsAny(value, ["undo", "reverse", "unlog"]) &&
           containsAny(value, ["set", "last rep", "logged set"]) {
            return proposal(.undoSet, "Undo Set",
                "Reverse the most recent completed set and update phone/Watch progress.")
        }
        if containsAny(value, ["undo", "reverse", "cancel"]) &&
           containsAny(value, ["workout", "strength session", "lifting session"]) {
            return proposal(.undoWorkout, "Undo Workout",
                "Stop the active iPhone workout and reverse only its session sets. The plan stays available.")
        }

        // Prescription edits are a first-class capability, not an answer
        // about how to use the manual editor. No guessed exercise IDs.
        let exerciseMatches = workout?.exercises.filter {
            value.contains($0.name.lowercased())
        } ?? []
        let matchedExercise = exerciseMatches.count == 1 ?
            exerciseMatches.first : nil
        let hasExerciseIntent = containsAny(value,
            ["exercise", "movement", "sets", "reps", "rest", "weight",
             "bench", "squat", "deadlift", "press", "curl", "row"]) ||
             matchedExercise != nil
        let isCalendarReschedule = containsAny(value,
            ["reschedule", "tomorrow", "next week", "move my workout",
             "shift my workout", "move today's workout"])
        if workout != nil && !isCalendarReschedule &&
           containsAny(value,
            ["edit ", "adjust ", "modify ", "change ", "increase ",
             "decrease ", "reduce ", "add ", "remove ", "delete ",
             "replace ", "swap ", "reorder ", "move ", "update ", "set "]) &&
           (hasExerciseIntent || containsAny(value,
              ["edit my workout", "edit today's workout", "edit workout",
               "change my workout", "modify my workout"])) {
            let isChangingSetCount = matchedExercise != nil &&
                (value.contains("set") || value.contains("rep")) &&
                !containsAny(value, ["add exercise", "remove exercise",
                                     "replace exercise", "swap exercise"])
            let operation: IMUNCoachExerciseOperation
            if isChangingSetCount { operation = .update }
            else if containsAny(value, ["remove ", "delete "]) { operation = .remove }
            else if containsAny(value, ["swap ", "replace "]) { operation = .replace }
            else if containsAny(value, ["add ", "insert "]) { operation = .add }
            else if containsAny(value, ["move ", "reorder "]) {
                operation = containsAny(value, ["down", "later", "last"]) ?
                    .moveDown : .moveUp
            } else { operation = .update }
            let targets = extractTargets(value)
            // "Add 2 sets" means change the current count, not add a movement.
            let relativeAddition = capture(value,
                pattern: #"\b(?:add|increase\s+by)\s+(\d{1,2})\s+sets?\b"#,
                group: 1).flatMap(Int.init)
            let relativeRemoval = capture(value,
                pattern: #"\b(?:remove|reduce\s+by|subtract)\s+(\d{1,2})\s+sets?\b"#,
                group: 1).flatMap(Int.init)
            let relativeSets = matchedExercise.flatMap { exercise -> Int? in
                let delta = relativeAddition ?? relativeRemoval.map { -$0 }
                guard let delta,
                      (1...12).contains(exercise.prescribedSets + delta) else { return nil }
                return exercise.prescribedSets + delta
            }
            let candidateName: String? = {
                if let matchedExercise { return matchedExercise.name }
                guard operation == .add || operation == .replace else { return nil }
                return capture(value,
                    pattern: #"(?:add|insert|replace|swap)\s+(?:an?\s+)?(?:exercise\s+)?([a-z][a-z0-9 '\-]{1,75}?)(?:\s+(?:to|with|for|at|into|in)\b|\s+\d|\s*$)"#,
                    group: 1)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }()
            let replacementName: String? = {
                guard operation == .replace else { return nil }
                return capture(value,
                    pattern: #"\b(?:with|to)\s+([a-z][a-z0-9 '\-]{1,75}?)(?:\s+\d|\s*$)"#,
                    group: 1)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }()
            return proposal(.editStrength, "Edit today's strength workout",
                "Select an exercise and review the exact change before saving. Prescribed targets can change; completed set records are preserved.",
                workoutID: workout?.id,
                workoutEdit: IMUNCoachWorkoutEditHint(
                    operation: operation, exerciseName: candidateName,
                    newName: replacementName, sets: relativeSets ?? targets.sets, repMin: targets.repMin,
                    repMax: targets.repMax, restSeconds: targets.rest,
                    weightLb: targets.weight))
        }

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

        if containsAny(value, ["set ", "switch ", "change ", "make ", "turn ",
                               "use ", "adjust ", "enable ", "disable "]) {
            let aliases: [(String, [String])] = [
                ("hcDesignReduceMotion", ["reduce motion", "animation"]),
                ("hcMotivationTone", ["motivation tone", "motivational tone"]),
                ("hcMotivationTranslation", ["bible translation",
                                              "scripture translation"]),
                ("hcMotivationShowTraining", ["motivation in training",
                                               "training motivation card"]),
                ("hcAggressiveProgression", ["aggressive progression",
                                               "strength progression"]),
                ("hcWeightIncrement", ["weight increment", "load increment"]),
                ("hcRunCueMinutes", ["run cue interval", "running cue interval"]),
                ("hcRunIntervals", ["show run intervals",
                                     "running intervals display"])
            ]
            let matches = aliases.filter { _, names in
                containsAny(value, names)
            }
            if matches.count == 1, let key = matches.first?.0,
               let preference = IMUNCoachPreference.byID(key) {
                let foundValue = preference.choices.first(where: { candidate in
                    let lower = candidate.lowercased()
                    if lower == "on" {
                        return containsAny(value, ["turn on", "enable ", "switch on"])
                    }
                    if lower == "off" {
                        return containsAny(value, ["turn off", "disable ", "switch off"])
                    }
                    return value.range(of:
                        "\\b" + NSRegularExpression.escapedPattern(for: lower) + "\\b",
                        options: .regularExpression) != nil
                })
                return proposal(.setAppPreference, "Change " + preference.title,
                    "Apply a typed iMun preference without changing recorded workouts or health permissions.",
                    parameter: foundValue ?? preference.choices.first,
                    settingKey: key)
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
            "finish", "complete", "adjust", "rename", "update", "edit ",
            "replace", "remove", "delete", "reorder"]) &&
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
        Valid registered actions and their exact effects:
        \(IMUNCoachActionCatalog.modelAllowlist)
        Use action="none" when the request is advice, medical interpretation,
        an unsupported operation or a health data edit you cannot authorize.
        Other optional fields: "parameter" string, "minutes" integer.
        For editStrength, optional: "operation" (update/add/replace/remove/
        moveUp/moveDown), "exerciseName" string, "sets" integer,
        "repMin"/"repMax" integers, "restSeconds" integer, "weightLb" number.
        Never invent an exercise ID. The user chooses the actual workout item.
        For setting values, use only valid app choices:
        - visual identity: fixed Selah Stone; theme customization is unsupported
        - tabs: training,progress,health,coach,settings
        - activity: run,weightlifting
        - motivation: off,original,performance,scripture,custom
        - haptics/voice/laps: on,off
        - rest seconds: 0,60,90,120,180
        For setAppPreference, use settingKey from this exact allowlist:
        \(IMUNCoachPreference.all.map { $0.id + ":" + $0.choices.joined(separator: "|") }.joined(separator: ", "))
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
        case "undoSet":
            return proposal(.undoSet, "Undo Set",
                "Review the latest set before reversing it.")
        case "undoWorkout":
            return proposal(.undoWorkout, "Undo Workout",
                "Reverse the active iPhone session without deleting its plan.")
        case "editStrength":
            guard let workout, workout.date == HCPlanBuilder.dateString(Date()),
                  !workout.isPreview else { return nil }
            let operation = (object["operation"] as? String)
                .flatMap(IMUNCoachExerciseOperation.init(rawValue:)) ?? .update
            let name = (object["exerciseName"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = name.map { String($0.prefix(80)) }
            func inRange(_ name: String, min: Int, max: Int) -> Int? {
                guard let number = object[name] as? Int,
                      (min...max).contains(number) else { return nil }
                return number
            }
            let sets = inRange("sets", min: 1, max: 12)
            let repMin = inRange("repMin", min: 1, max: 30)
            let repMax = inRange("repMax", min: 1, max: 40)
            let rest = inRange("restSeconds", min: 15, max: 360)
            let restValid = rest.flatMap { $0.isMultiple(of: 15) ? $0 : nil }
            let weight = (object["weightLb"] as? NSNumber)?.doubleValue
            let safeWeight = weight.flatMap {
                $0.isFinite && (0...1500).contains($0) ? $0 : nil
            }
            return proposal(.editStrength, "Edit today's workout",
                "Review the exact exercise, prescription and target values. No completed set logs will be invented or deleted.",
                workoutID: workout.id,
                workoutEdit: IMUNCoachWorkoutEditHint(
                    operation: operation, exerciseName: candidate,
                    newName: (object["replacementName"] as? String).map {
                        String($0.prefix(80))
                    },
                    sets: sets, repMin: repMin, repMax: repMax,
                    restSeconds: restValid, weightLb: safeWeight))
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
        case "setAppPreference":
            guard let key = object["settingKey"] as? String,
                  let pref = IMUNCoachPreference.byID(key) else { return nil }
            let selected = value.flatMap {
                pref.choices.contains($0) ? $0 : nil
            } ?? pref.choices.first
            return proposal(.setAppPreference, "Change " + pref.title,
                "Review this whitelisted setting. No health-sharing or account permissions are modified.",
                parameter: selected, settingKey: key)
        case "setTheme":
            return nil
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

    private static func capture(_ text: String, pattern: String, group: Int) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern,
                                                         options: .caseInsensitive) else { return nil }
        let source = text as NSString
        guard let match = expression.firstMatch(in: text, options: [],
                    range: NSRange(location: 0, length: source.length)),
              group < match.numberOfRanges,
              match.range(at: group).location != NSNotFound else { return nil }
        return source.substring(with: match.range(at: group))
    }

    private static func extractTargets(_ text: String)
        -> (sets: Int?, repMin: Int?, repMax: Int?, rest: Int?, weight: Double?) {
        var sets = capture(text, pattern: #"\b(\d{1,2})\s*sets?\b"#,
                           group: 1).flatMap(Int.init)
        var low = capture(text, pattern:
            #"\b(\d{1,2})\s*(?:to|-|–)\s*\d{1,2}\s*reps?\b"#,
            group: 1).flatMap(Int.init)
        var high = capture(text, pattern:
            #"\b\d{1,2}\s*(?:to|-|–)\s*(\d{1,2})\s*reps?\b"#,
            group: 1).flatMap(Int.init)
        if low == nil {
            low = capture(text, pattern: #"\b(\d{1,2})\s*reps?\b"#,
                          group: 1).flatMap(Int.init)
            high = low
        }
        // Common shorthand: 4×8–10 or 3x12.
        if let shorthand = capture(text,
            pattern: #"\b(\d{1,2})\s*[x×]\s*\d{1,2}"#,
            group: 1).flatMap(Int.init) {
            sets = sets ?? shorthand
            low = low ?? capture(text,
                pattern: #"\b\d{1,2}\s*[x×]\s*(\d{1,2})"#,
                group: 1).flatMap(Int.init)
            high = high ?? capture(text,
                pattern: #"\b\d{1,2}\s*[x×]\s*\d{1,2}\s*[-–]\s*(\d{1,2})"#,
                group: 1).flatMap(Int.init) ?? low
        }
        var rest = capture(text, pattern:
            #"\b(\d{1,3})\s*(?:seconds?|secs?)\s*(?:of\s+)?rest\b"#,
            group: 1).flatMap(Int.init)
        rest = rest ?? capture(text, pattern:
            #"\brest\s*(?:for\s*)?(\d{1,3})\s*(?:seconds?|secs?)\b"#,
            group: 1).flatMap(Int.init)
        if rest == nil, let minutes = capture(text, pattern:
            #"\b(\d{1,2})\s*(?:minutes?|mins?)\s*(?:of\s+)?rest\b"#,
            group: 1).flatMap(Int.init) { rest = minutes * 60 }
        let weight = capture(text,
            pattern: #"\b(\d{1,4}(?:\.\d+)?)\s*(?:lb|lbs|pounds?)\b"#,
            group: 1).flatMap(Double.init)
        return ((sets ?? 0) >= 1 && (sets ?? 0) <= 12 ? sets : nil,
                (low ?? 0) >= 1 && (low ?? 0) <= 30 ? low : nil,
                (high ?? 0) >= 1 && (high ?? 0) <= 40 ? high : nil,
                (rest ?? 0) >= 15 && (rest ?? 0) <= 360 &&
                (rest ?? 0).isMultiple(of: 15) ? rest : nil,
                (weight ?? -1) >= 0 && (weight ?? -1) <= 1500 ? weight : nil)
    }

    private static func containsAny(_ input: String, _ terms: [String]) -> Bool {
        terms.contains { input.contains($0) }
    }

    private static func proposal(_ kind: IMUNCoachActionKind,
                                 _ title: String, _ explanation: String,
                                 workoutID: String? = nil, date: Date? = nil,
                                 theme: String? = nil,
                                 parameter: String? = nil,
                                 workoutEdit: IMUNCoachWorkoutEditHint? = nil,
                                 settingKey: String? = nil)
        -> IMUNCoachActionProposal {
        IMUNCoachActionProposal(kind: kind, title: title, explanation: explanation,
                                suggestedWorkoutID: workoutID,
                                suggestedDate: date, themeID: theme,
                                parameter: parameter, workoutEdit: workoutEdit,
                                settingKey: settingKey)
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


/// Typed editor behind Coach's confirmation. It edits the prescribed plan
/// through PhoneWorkoutBridge, never bypassing workout validation or cloud sync.
struct IMUNCoachWorkoutEditForm: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Binding var operation: IMUNCoachExerciseOperation
    @Binding var selectedExerciseID: String
    @Binding var exerciseName: String
    @Binding var instructions: String
    @Binding var sets: Int
    @Binding var repMin: Int
    @Binding var repMax: Int
    @Binding var restSeconds: Int
    @Binding var weightText: String
    let onSelectExercise: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Picker("Edit type", selection: $operation) {
                ForEach(IMUNCoachExerciseOperation.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .tint(HCDesign.electric)

            if operation != .add {
                Picker("Exercise", selection: $selectedExerciseID) {
                    Text("Choose exercise").tag("")
                    ForEach(coach.workout?.exercises ?? []) { exercise in
                        Text(exercise.name).tag(exercise.id)
                    }
                }
                .tint(HCDesign.electric)
                .onChange(of: selectedExerciseID) { _, value in
                    onSelectExercise(value)
                }
            }

            if operation == .add || operation == .replace {
                TextField("Exercise name", text: $exerciseName)
                    .textInputAutocapitalization(.words)
                    .padding(10)
                    .background(HCDesign.raised,
                        in: RoundedRectangle(cornerRadius: 9))
                TextField("Instructions (optional)", text: $instructions, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(10)
                    .background(HCDesign.raised,
                        in: RoundedRectangle(cornerRadius: 9))
            }

            if operation == .update || operation == .add ||
               operation == .replace {
                Stepper("Working sets: \(sets)", value: $sets, in: 1...12)
                Stepper("Minimum reps: \(repMin)", value: $repMin, in: 1...30)
                Stepper("Maximum reps: \(repMax)", value: $repMax, in: 1...40)
                Stepper("Rest: \(restSeconds) seconds", value: $restSeconds,
                        in: 15...360, step: 15)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Suggested load (lb)")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    TextField("Optional", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                Text("Suggested load is not a record of weight lifted. Clear it to leave the target unspecified.")
                    .font(.caption2).foregroundStyle(HCDesign.secondary)
            } else if operation == .remove || operation == .replace {
                Text("iMun will not remove or replace an exercise with completed or active sets.")
                    .font(.caption).foregroundStyle(HCDesign.secondary)
            } else {
                Text("Reordering keeps exercise identities and recorded workout history intact.")
                    .font(.caption).foregroundStyle(HCDesign.secondary)
            }
        }
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
    @Binding var editOperation: IMUNCoachExerciseOperation
    @Binding var selectedEditExerciseID: String
    @Binding var editExerciseName: String
    @Binding var editInstructions: String
    @Binding var editSets: Int
    @Binding var editRepMin: Int
    @Binding var editRepMax: Int
    @Binding var editRestSeconds: Int
    @Binding var editWeightText: String
    @Binding var preferenceKey: String
    @Binding var preferenceValue: String
    let onSelectEditExercise: (String) -> Void
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
                if action.kind == .setAppPreference {
                    Picker("App setting", selection: $preferenceKey) {
                        ForEach(IMUNCoachPreference.all) { setting in
                            Text(setting.title).tag(setting.id)
                        }
                    }
                    .tint(HCDesign.electric)
                    .onChange(of: preferenceKey) { _, newKey in
                        preferenceValue = IMUNCoachPreference.byID(newKey)?
                            .choices.first ?? ""
                    }
                    if let setting = IMUNCoachPreference.byID(preferenceKey) {
                        Picker("New value", selection: $preferenceValue) {
                            ForEach(setting.choices, id: \.self) { option in
                                Text(option.capitalized).tag(option)
                            }
                        }
                        .tint(HCDesign.electric)
                    }
                    Text("Only supported appearance, motivation and training preferences are editable here. Health permissions and account data aren't exposed.")
                        .font(.caption2)
                        .foregroundStyle(HCDesign.secondary)
                }
                if action.kind == .editStrength {
                    IMUNCoachWorkoutEditForm(
                        operation: $editOperation,
                        selectedExerciseID: $selectedEditExerciseID,
                        exerciseName: $editExerciseName,
                        instructions: $editInstructions,
                        sets: $editSets,
                        repMin: $editRepMin,
                        repMax: $editRepMax,
                        restSeconds: $editRestSeconds,
                        weightText: $editWeightText,
                        onSelectExercise: onSelectEditExercise)
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
                   action.kind != .renameStrength &&
                   action.kind != .editStrength &&
                   action.kind != .setAppPreference {
                    Text("Selected value: \(parameter)")
                        .font(.caption2)
                        .foregroundStyle(HCDesign.secondary)
                }
                HStack(spacing: 10) {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                        .tint(HCDesign.secondary)
                    Button(action.kind == .undoWorkout ? "Undo Workout" :
                           action.kind == .undoSet ? "Undo Set" : "Confirm action",
                           action: onConfirm)
                        .buttonStyle(.borderedProminent)
                        .tint(action.kind == .undoWorkout ?
                              HCDesign.caution : HCDesign.electric)
                        .disabled(!canConfirm)
                }
                Text("IsAIah never makes app changes without your confirmation.")
                    .font(.caption2)
                    .foregroundStyle(HCDesign.secondary)
            }
        }
    }
}
