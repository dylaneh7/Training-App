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


// Searchable, editable strength exercise library. Additions are data, not
// guesses derived from the user's previous set slot or equipment.
struct HCLibraryExercise: Identifiable, Hashable {
    let name: String
    let group: String
    let equipment: String
    let instructions: String
    var id: String { HCProgramCatalog.normalized(name) }
}

enum HCExerciseLibrary {
    private static func ex(_ name: String, _ group: String, _ gear: String, _ steps: String) -> HCLibraryExercise {
        .init(name: name, group: group, equipment: gear, instructions: steps)
    }
    static let all: [HCLibraryExercise] = [
        ex("Flat barbell bench press","Chest","Barbell","Retract shoulder blades, keep feet planted, lower to mid-chest and press in control."),
        ex("Flat dumbbell bench press","Chest","Dumbbells","Set shoulders gently back, lower each dumbbell through comfortable range, and press evenly."),
        ex("Incline dumbbell press","Chest","Dumbbells","Use a moderate incline, keep forearms aligned, and press without arching."),
        ex("Incline barbell bench press","Chest","Barbell","Set a moderate incline, lower to upper chest, and press smoothly."),
        ex("Paused bench press","Chest","Barbell","Pause briefly on chest without bouncing; use a spotter as appropriate."),
        ex("Machine chest press","Chest","Machine","Adjust handles to chest height and move without bouncing."),
        ex("Smith machine bench press","Chest","Smith machine","Align bench to machine path and engage safety catches."),
        ex("Cable chest fly","Chest","Cable","Maintain soft elbows and draw arms together without using momentum."),
        ex("Push-up","Chest","Bodyweight","Brace trunk, lower chest with control, push up."),
        ex("Seated dumbbell shoulder press","Shoulders","Dumbbells","Stay braced and press overhead in a comfortable range."),
        ex("Barbell overhead press","Shoulders","Barbell","Brace trunk and press bar overhead without back overextension."),
        ex("Machine shoulder press","Shoulders","Machine","Adjust seat and keep a smooth controlled pressing arc."),
        ex("Cable lateral raise","Shoulders","Cable","Raise to shoulder height with stable torso and soft elbow."),
        ex("Dumbbell lateral raise","Shoulders","Dumbbells","Lift out to sides without shrugging or swinging."),
        ex("Reverse pec deck","Shoulders","Machine","Keep chest on pad and open arms without momentum."),
        ex("Cable rear-delt fly","Shoulders","Cable","Open arms with a stable chest and controlled return."),
        ex("Neutral-grip lat pulldown","Back","Cable","Drive elbows down toward ribs and avoid torso swinging."),
        ex("Wide-grip lat pulldown","Back","Cable","Pull elbows down toward chest; avoid behind-neck pulling."),
        ex("Pull-up","Back","Bodyweight","Use full comfortable range and avoid kipping."),
        ex("Weighted pull-up","Back","Bodyweight + added load","Record only attached extra weight, not bodyweight."),
        ex("Seated Row","Back","Cable","Pull to midsection with a stable torso and slow return."),
        ex("Chest-supported T-bar row","Back","Machine","Brace chest, pull elbows back and control the release."),
        ex("One-arm dumbbell row","Back","Dumbbells","Support torso and row elbow toward hip without twisting."),
        ex("Barbell bent-over row","Back","Barbell","Hinge, brace and row toward lower ribs without jerking."),
        ex("Wide high row","Back","Machine","Pull handles with upper back while chest stays supported."),
        ex("Straight-arm cable pulldown","Back","Cable","Sweep arms down with soft elbows and quiet trunk."),
        ex("Face pull with external rotation","Back","Cable","Pull rope to face and externally rotate comfortably."),
        ex("Dumbbell shrug","Traps","Dumbbells","Elevate shoulders without neck rotation or swinging."),
        ex("Cable curl","Arms","Cable","Keep elbows at sides and curl without torso movement."),
        ex("Incline dumbbell curl","Arms","Dumbbells","Keep upper arms behind torso on inclined bench."),
        ex("Hammer curl","Arms","Dumbbells","Maintain neutral grip and control both directions."),
        ex("Preacher curl","Arms","Machine / EZ bar","Keep upper arms on pad and avoid bouncing."),
        ex("EZ-bar curl","Arms","EZ bar","Curl smoothly while keeping elbows in place."),
        ex("Rope pressdown","Arms","Cable","Pin upper arms and extend elbows without swinging."),
        ex("Overhead cable triceps extension","Arms","Cable","Keep elbows stable and ribs down."),
        ex("Close-grip bench press","Arms","Barbell","Use comfortable grip and keep wrists neutral."),
        ex("Back squat","Legs","Barbell","Brace and squat with consistent foot contact and depth."),
        ex("Hack squat","Legs","Machine","Keep pelvis supported and control knee tracking."),
        ex("Front squat","Legs","Barbell","Keep elbows elevated and brace torso."),
        ex("Romanian deadlift","Legs","Barbell","Hinge at hips with bar close and spine neutral."),
        ex("Trap-bar deadlift","Legs","Trap bar","Brace trunk and drive through floor."),
        ex("Leg press","Legs","Machine","Keep low back on pad and press evenly."),
        ex("Bulgarian split squat","Legs","Dumbbells","Keep hips square and front foot planted."),
        ex("Leg extension","Legs","Machine","Adjust knee pivot and extend under control."),
        ex("Seated leg curl","Legs","Machine","Curl without lifting hips or bouncing."),
        ex("Hip thrust","Legs","Barbell / machine","Keep ribs down, drive hips and avoid hyperextension."),
        ex("Standing calf raise","Legs","Machine","Control deep stretch and top contraction."),
        ex("Seated calf raise","Legs","Machine","Use controlled ankle range and pause at top."),
        ex("Cable crunch","Core","Cable","Flex torso with hips stable and exhale."),
        ex("Ab wheel rollout","Core","Bodyweight","Brace trunk and avoid lower-back arching.")
    ]
}

struct HCPerformanceSet: Hashable {
    let exercise: String
    let weightLb: Double
    let reps: Int
    let rir: Double?
    let date: String
}

struct HCLoadSuggestion {
    let weightLb: Double?
    let reps: Int
    let confidence: String
    let explanation: String
    let perDumbbell: Bool
}

/// Transparent conservative estimates for cross-implement exercise variations.
/// ACSM's load increases are conditional on performance; the 0.75 conversion
/// below is NOT a universal research-established barbell:dumbbell ratio.
enum HCProgressionEngine {
    static func signature(_ name: String) -> (family: String, gear: String) {
        let n = HCProgramCatalog.normalized(name)
        let gear = n.contains("db") ? "dumbbell" : n.contains("barbell") ? "barbell" :
            n.contains("cable") ? "cable" : "machine"
        if n.contains("bench") && n.contains("press") && !n.contains("incline") { return ("flat-bench",gear) }
        if n.contains("incline") && n.contains("press") { return ("incline-press",gear) }
        if n.contains("shoulder") && n.contains("press") { return ("shoulder-press",gear) }
        if n.contains("pulldown") { return ("pulldown",gear) }
        if n.contains("row") { return ("row",gear) }
        return (HCProgramCatalog.identity(for: name),gear)
    }
    static func suggest(_ exercise: HCExercise,
                        history: [HCPerformanceSet],
                        aggressive: Bool = true,
                        returning: Bool = false) -> HCLoadSuggestion {
        let target = max(1,exercise.repMin)
        let name = HCProgramCatalog.normalized(exercise.name)
        let dest = signature(exercise.name)
        let perDB = dest.gear == "dumbbell"
        let candidates = history.filter {$0.weightLb > 0 && $0.reps > 0 && $0.reps <= 20}
        let matching = candidates.filter {HCProgramCatalog.normalized($0.exercise)==name}
            .sorted {$0.date > $1.date}
        let exact = !matching.isEmpty
        let source = matching.first ?? candidates.filter {signature($0.exercise).family == dest.family}
            .sorted {$0.date > $1.date}.first
        guard let previous = source else {
            return .init(weightLb:nil,reps:target,confidence:"No baseline",explanation:"No comparable completed sets. Use a comfortable starting load; record reps and RIR to teach the system.",perDumbbell:perDB)
        }
        let from = signature(previous.exercise)
        let rir = max(0,min(4,previous.rir ?? 2))
        let earnedIncrease = exact && aggressive && !returning &&
            previous.reps >= exercise.repMax && (previous.rir ?? 1) >= 1
        let estimated1RM = previous.weightLb * (1 + (Double(previous.reps)+rir)/30)
        var estimate = estimated1RM / (1 + (Double(target)+(returning ? 3:2))/30)
        var confidence = exact ? "High" : "Medium"
        if exact {
            if aggressive && !returning && previous.reps >= exercise.repMax && (previous.rir ?? 1) >= 1 {
                estimate = previous.weightLb*1.025
            } else {
                estimate = min(estimate,previous.weightLb)
            }
        } else if from.family == "flat-bench" && dest.family == "flat-bench"
                    && from.gear == "barbell" && dest.gear == "dumbbell" {
            estimate *= 0.75 / 2
            confidence = "Low · barbell → dumbbells"
        } else if from.family == "flat-bench" && dest.family == "flat-bench"
                    && from.gear == "dumbbell" && dest.gear == "barbell" {
            estimate *= 2 / 0.75
            confidence = "Low · dumbbells → barbell"
        } else if from.gear == dest.gear {
            estimate *= 0.90
            confidence = "Medium · movement variation"
        } else {
            return .init(weightLb:nil,reps:target,confidence:"Related history only",explanation:"Previous \(previous.exercise): \(previous.weightLb.formatted()) lb × \(previous.reps). Machine, cable and dumbbell loads cannot be reliably interchanged. Choose a test load.",perDumbbell:perDB)
        }
        if returning {estimate *= 0.9}
        if !exact {estimate *= 0.95}
        let step = perDB ? 2.5 : (estimate >= 50 ? 5.0 : 2.5)
        // When a lifter *earns* a load increase, round up to an actual
        // available increment; flooring 155*1.025 to 155 would prevent progress.
        let suggestion = earnedIncrease
            ? max(previous.weightLb + step, ceil(estimate/step)*step)
            : max(step, floor(estimate/step)*step)
        let reason = exact
            ? "Last comparable set: \(previous.weightLb.formatted()) lb × \(previous.reps) @\(previous.rir.map{$0.formatted()} ?? "?") RIR. Progress by reps first; raise weight when you reach your rep ceiling with control."
            : "From \(previous.exercise) \(previous.weightLb.formatted()) lb × \(previous.reps). Cross-variation conversion is a cautious starting estimate, not a personal strength equivalence. Recalibrate after the first set."
        return .init(weightLb:suggestion,reps:target,confidence:confidence,explanation:reason,perDumbbell:perDB)
    }
}
