import Foundation

/// Default prescriptions until Health Coach exposes a stable versioned plan API.
/// The one-off Saturday program mirrors the Health Coach session on 2026-11-14.
/// Exercise indexes map to the existing PWA set fields ("0-1", "0-2", ...).
enum HCProgramCatalog {
    struct Template {
        let name: String
        let original: String
        let sets: Int
        let lo: Int
        let hi: Int
        let rest: Int

        init(_ name: String, original: String? = nil, _ sets: Int, _ lo: Int, _ hi: Int, _ rest: Int) {
            self.name = name
            self.original = original ?? name
            self.sets = sets
            self.lo = lo
            self.hi = hi
            self.rest = rest
        }
    }

    static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "—", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "–", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "dumbbell", with: "db")
            .replacingOccurrences(of: "pressdown", with: "pushdown")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func identity(for movement: String) -> String {
        let value = normalized(movement)
        if value.contains("bench") && value.contains("barbell") && value.contains("press") {
            return "barbell bench press"
        }
        if value.contains("neutral") && value.contains("pulldown") {
            return "neutral lat pulldown"
        }
        return value
    }

    static func templates(for sessionKey: String) -> [Template] {
        let key = String(sessionKey.split(separator: "-").last ?? "")
        switch key {
        case "SatUpper":
            return [
                Template("Flat barbell bench press", 3, 6, 8, 180),
                Template("Neutral-grip lat pulldown", 3, 8, 12, 120),
                Template("Incline dumbbell press", 2, 8, 10, 120),
                Template("Seated Row", 3, 8, 12, 120),
                Template("Seated dumbbell shoulder press", 2, 8, 10, 120),
                Template("Cable lateral raise", 2, 12, 15, 75),
                Template("Reverse pec deck", 2, 12, 15, 75),
                Template("Rope pressdown", 2, 10, 15, 75),
                Template("Hammer curl", 2, 10, 12, 75)
            ]
        case "Mon":
            return [
                Template("Flat barbell bench press", 4, 4, 8, 180),
                Template("Seated dumbbell shoulder press", original:"Incline dumbbell press", 3, 5, 8, 150),
                Template("Incline dumbbell press", original:"Weighted dip — chest bias", 3, 8, 12, 120),
                Template("Cable chest fly", original:"Seated dumbbell shoulder press", 3, 10, 15, 90),
                Template("Cable lateral raise", original:"Chest-supported lateral raise", 3, 12, 15, 75),
                Template("Reverse pec deck", original:"Standing lateral raise", 3, 12, 15, 75),
                Template("Overhead cable triceps extension", 3, 10, 15, 75),
                Template("Rope pressdown", 3, 10, 15, 75)
            ]
        case "Tue":
            return [
                Template("Neutral-grip lat pulldown", original:"Weighted pull-up / neutral pulldown", 4, 6, 10, 150),
                Template("Chest-supported T-bar row", 4, 6, 10, 150),
                Template("Single-arm cable lat row — elbow to hip", 3, 8, 12, 120),
                Template("Wide high row", 3, 8, 12, 120),
                Template("Straight-arm cable pulldown", 3, 10, 15, 90),
                Template("Reverse pec deck", original:"Dumbbell shrug", 3, 12, 15, 75),
                Template("Face pull with external rotation", original:"Cable Y-raise", 2, 12, 15, 75),
                Template("Incline dumbbell curl", 3, 10, 12, 75),
                Template("Preacher curl", 3, 8, 12, 75),
                Template("Hammer curl", 3, 10, 12, 75)
            ]
        case "Wed", "UpperThu":
            return [
                Template("Paused bench press", 3, 6, 10, 150),
                Template("Low-to-high cable fly", 3, 10, 15, 90),
                Template("Neutral-grip pulldown", 3, 8, 12, 120),
                Template("Chest-supported machine row", 3, 8, 12, 120),
                Template("Cable lateral raise", 3, 12, 15, 75),
                Template("Cable rear-delt fly", 3, 12, 15, 75),
                Template("Rope pressdown", 3, 10, 15, 75),
                Template("Cable curl", 3, 10, 15, 75)
            ]
        case "Thu", "LegsFri":
            return [
                Template("Back squat / hack squat", 3, 5, 8, 180),
                Template("Romanian deadlift", 3, 6, 10, 180),
                Template("Leg press", 3, 8, 12, 150),
                Template("Bulgarian split squat", 3, 8, 10, 120),
                Template("Leg extension", 3, 12, 15, 75),
                Template("Seated leg curl", 3, 10, 15, 75),
                Template("Hip thrust", 3, 8, 12, 120),
                Template("Standing calf raise", 3, 10, 15, 75)
            ]
        default:
            return []
        }
    }

    static func makeWorkout(
        date: String, sessionKey: String, title: String,
        savedHistory: [String: Double], isPreview: Bool = false
    ) -> HCWorkout {
        let returning = sessionKey.hasSuffix("SatUpper")
        let exercises = templates(for: sessionKey).enumerated().map { index, t in
            let previous = savedHistory[identity(for: t.name)]
            let load: Double?
            if !isPreview, let previous, previous > 0 {
                let multiplier = returning ? 0.90 : 1.0
                let step: Double = previous >= 40 ? 5 : 2.5
                load = max(step, (previous * multiplier / step).rounded(.down) * step)
            } else {
                load = nil
            }
            return HCExercise(
                id: "\(sessionKey)-\(index)",
                name: t.name,
                originalName: t.original,
                exerciseIndex: index,
                prescribedSets: t.sets,
                repMin: t.lo,
                repMax: t.hi,
                suggestedWeightLb: load,
                restSeconds: t.rest
            )
        }

        return HCWorkout(
            id: "\(date)-\(sessionKey)",
            date: date,
            sessionKey: sessionKey,
            title: title,
            exercises: exercises,
            isPreview: isPreview
        )
    }
}
