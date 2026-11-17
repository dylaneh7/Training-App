import Foundation

/// Explicit allowlisted user actions. Coach's prose is never executed as code,
/// SQL, or an unreviewed instruction to mutate the training database.
enum IMUNCoachActionKind: Equatable {
    case moveWorkout, completeRun, syncWatch, setTheme
}

struct IMUNCoachActionProposal: Identifiable {
    let id = UUID()
    let kind: IMUNCoachActionKind
    let title: String
    let explanation: String
    let suggestedWorkoutID: String?
    let suggestedDate: Date?
    let themeID: String?
}

/// A small deterministic first-stage command recognizer. The server Coach
/// continues handling normal questions. Ambiguous actions require the
/// athlete to select the actual workout/date before confirmation.
enum IMUNCoachActionInterpreter {
    static func propose(_ request: String,
                        sessions: [HCPlannedSession],
                        run: HCRunPlan?) -> IMUNCoachActionProposal? {
        let value = request.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let move = containsAny(value, ["move ", "reschedule ", "shift "])
            && containsAny(value, ["workout", "session", "run", "lift",
                                    "training", "exercise"])
        if move {
            let sourceDate = matchingDate(value, terms: ["tomorrow", "today", "monday",
                "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"],
                                          source: true)
            let candidates = sessions.filter { session in
                let textMatches = value.contains(session.title.lowercased())
                let dateMatches = sourceDate.map {
                    session.date == HCPlanBuilder.dateString($0)
                } ?? false
                return textMatches || dateMatches
            }
            let match = candidates.count == 1 ? candidates[0] : nil
            let destinationPhrase = value.components(separatedBy: " to ").dropFirst().joined(separator: " to ")
            let destination = matchingDate(destinationPhrase.isEmpty ? value : destinationPhrase,
                                           terms: [], source: false)
            return IMUNCoachActionProposal(
                kind: .moveWorkout,
                title: "Reschedule a workout",
                explanation: "Choose the exact session and destination date. Original completed records stay on their original days.",
                suggestedWorkoutID: match?.id,
                suggestedDate: destination,
                themeID: nil)
        }

        if containsAny(value, ["complete", "completed", "finish", "finished",
                               "done", "check off", "mark off"]) &&
           containsAny(value, ["run", "running"]) &&
           containsAny(value, ["mark ", "i ", "my ", "check ", "complete ", "finished"]) {
            guard let run, run.date == HCPlanBuilder.dateString(Date()),
                  !run.isCompleted else { return nil }
            return IMUNCoachActionProposal(
                kind: .completeRun,
                title: "Mark today's run completed",
                explanation: "This records your confirmation only. It won't invent distance, heart rate, pace, or an Apple Health workout.",
                suggestedWorkoutID: run.id, suggestedDate: nil, themeID: nil)
        }

        if containsAny(value, ["sync ", "send ", "refresh "]) &&
           containsAny(value, ["watch", "apple watch"]) {
            return IMUNCoachActionProposal(
                kind: .syncWatch,
                title: "Refresh iMun Watch workout",
                explanation: "Publish and deliver the current phone schedule using the existing phone and cloud sync routes.",
                suggestedWorkoutID: nil, suggestedDate: nil, themeID: nil)
        }

        if containsAny(value, ["theme", "appearance", "design", "look"]) &&
           containsAny(value, ["switch", "change", "use", "set", "make"]) {
            let matches = IMUNPreset.allCases.filter { preset in
                value.contains(preset.title.lowercased()) ||
                    value.contains(preset.rawValue.lowercased())
            }
            if matches.count == 1, let chosen = matches.first {
                return IMUNCoachActionProposal(
                    kind: .setTheme,
                    title: "Change appearance to \(chosen.title)",
                    explanation: "Update iMun's design preset. Training records and motivation preferences remain unchanged.",
                    suggestedWorkoutID: nil, suggestedDate: nil,
                    themeID: chosen.rawValue)
            }
        }
        return nil
    }

    private static func containsAny(_ value: String, _ fragments: [String]) -> Bool {
        fragments.contains { value.contains($0) }
    }

    private static func matchingDate(_ request: String,
                                     terms: [String],
                                     source: Bool) -> Date? {
        let value = request.lowercased()
        let cal = Calendar.current
        let now = cal.startOfDay(for: Date())
        if let match = value.range(of: #"\b20\d\d-\d\d-\d\d\b"#,
                                   options: .regularExpression) {
            return HCPlanBuilder.startOfDate(String(value[match]))
        }
        if value.contains("tomorrow") {
            return cal.date(byAdding: .day, value: 1, to: now)
        }
        if value.contains("today") { return now }

        let weekdays = ["sunday", "monday", "tuesday", "wednesday",
                        "thursday", "friday", "saturday"]
        for (index, name) in weekdays.enumerated() where value.contains(name) {
            let target = index + 1
            let current = cal.component(.weekday, from: now)
            let delta = (target - current + 7) % 7
            let offset = value.contains("next " + name) && delta == 0 ? 7 : delta
            return cal.date(byAdding: .day, value: offset, to: now)
        }
        _ = terms
        _ = source
        return nil
    }
}
