import SwiftUI
#if os(iOS)
import UIKit
#endif

// Shared between iPhone and Apple Watch. Theme changes must never touch
// workout storage, login credentials, or the currently running training clock.
enum IMUNPreset: String, CaseIterable, Identifiable {
    case heritage, retro, techno, coast, fieldNotes, discipline, atelier, rally
    var id: String { rawValue }
    var title: String {
        switch self {
        case .heritage: return "Heritage"
        case .retro: return "Retro"
        case .techno: return "Techno"
        case .coast: return "Coast"
        case .fieldNotes: return "Field Notes"
        case .discipline: return "Discipline"
        case .atelier: return "Atelier"
        case .rally: return "Rally"
        }
    }
    var tagline: String {
        switch self {
        case .heritage: return "Sporting club · forest, cream & oxblood"
        case .retro: return "Warm analog · vintage athletic scoreboard"
        case .techno: return "Telemetry · focused contrast & precision"
        case .coast: return "Sea glass · sand & open breathing room"
        case .fieldNotes: return "Trail journal · moss, stone & contour"
        case .discipline: return "Essential monochrome · no distraction"
        case .atelier: return "Editorial restraint · impeccable hierarchy"
        case .rally: return "Competition · angular split-time energy"
        }
    }
    var symbol: String {
        switch self {
        case .heritage: return "leaf"
        case .retro: return "stopwatch"
        case .techno: return "waveform.path.ecg"
        case .coast: return "water.waves"
        case .fieldNotes: return "mountain.2"
        case .discipline: return "line.3.horizontal.decrease"
        case .atelier: return "text.alignleft"
        case .rally: return "flag.checkered"
        }
    }
    var accent: String {
        switch self {
        case .heritage: return "A65D60"
        case .retro: return "E9A25A"
        case .techno: return "D4324F"
        case .coast: return "63B4B3"
        case .fieldNotes: return "B8CB86"
        case .discipline: return "E7E7E3"
        case .atelier: return "CBA97F"
        case .rally: return "F5A14A"
        }
    }
    var accentTwo: String {
        switch self {
        case .heritage: return "DCCDA8"
        case .retro: return "C4D2A8"
        case .techno: return "71D8DA"
        case .coast: return "E2CFAC"
        case .fieldNotes: return "D1B791"
        case .discipline: return "9EADB2"
        case .atelier: return "E5D6C2"
        case .rally: return "E4E8EB"
        }
    }
    var darkBackground: String {
        switch self {
        case .heritage: return "12221D"
        case .retro: return "292320"
        case .techno: return "070C16"
        case .coast: return "0B2832"
        case .fieldNotes: return "1B241D"
        case .discipline: return "0E1011"
        case .atelier: return "1F1A19"
        case .rally: return "13191F"
        }
    }
    var darkSurface: String {
        switch self {
        case .heritage: return "23332B"
        case .retro: return "3A302B"
        case .techno: return "111D2A"
        case .coast: return "17404A"
        case .fieldNotes: return "2C392B"
        case .discipline: return "1D2224"
        case .atelier: return "302825"
        case .rally: return "202D38"
        }
    }
    var lightBackground: String {
        switch self {
        case .heritage: return "F1EBDD"
        case .retro: return "F2E6D3"
        case .techno: return "E8EDF1"
        case .coast: return "F2F5EE"
        case .fieldNotes: return "EAE9D9"
        case .discipline: return "F5F5F2"
        case .atelier: return "F4EDE3"
        case .rally: return "F0F2F3"
        }
    }
    var defaultShape: String {
        switch self {
        case .heritage, .retro, .coast: return "rounded"
        case .techno, .discipline: return "square"
        case .fieldNotes: return "asymmetric"
        case .atelier: return "asymmetric"
        case .rally: return "chamfered"
        }
    }
    var defaultFont: String {
        switch self {
        case .heritage, .atelier: return "serif"
        case .retro: return "rounded"
        case .techno, .rally: return "monospaced"
        case .coast: return "rounded"
        case .fieldNotes: return "serif"
        case .discipline: return "standard"
        }
    }
    var defaultDensity: String {
        switch self {
        case .atelier, .coast: return "airy"
        case .techno, .rally, .discipline: return "compact"
        default: return "balanced"
        }
    }
    var defaultMotif: String {
        switch self {
        case .heritage, .atelier: return "keylines"
        case .retro: return "stripes"
        case .techno, .rally: return "grid"
        case .coast: return "glow"
        case .fieldNotes: return "contours"
        case .discipline: return "none"
        }
    }
}

struct IMUNPalette {
    let canvas: Color
    let surface: Color
    let raised: Color
    let outline: Color
    let ink: Color
    let secondary: Color
    let accent: Color
    let supporting: Color
}

/// Visual tokens are data only: no file I/O beyond preferences.
/// A single, permanent iMun identity — Selah Stone.
/// Visual vocabulary: the ash of the wilderness, limestone, parchment and
/// quiet silver. References are conceptual; no faith or worship preference
/// is imposed on athletes. Scripture content remains separately opt-in.
enum IMUNStyle {
    // Older user-customization keys may remain in UserDefaults for migration,
    // but they no longer change visuals or sync to a second device.
    static var preset: IMUNPreset { .heritage }
    static var appearanceMode: String { "dark" }
    static var customPalette: Bool { false }
    static var customGeometry: Bool { false }
    static var cardShape: String { "rounded" }
    static var font: String { "serif" }
    static var buttonShape: String { "rounded" }
    static var density: String { "balanced" }
    static var motif: String { "keylines" }
    static var navigation: String { "standard" }
    static var progressStyle: String { "ring" }
    static var animationsEnabled: Bool {
        !UserDefaults.standard.bool(forKey: "hcDesignReduceMotion")
    }
    static var preferredScheme: ColorScheme? { .dark }
    static var padding: CGFloat { 17 }
    static var radius: CGFloat { 15 }
    static var headingDesign: Font.Design { .serif }

    static func resolvedColor(_ hex: String) -> Color {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let number = UInt64(clean, radix: 16) else {
            return .white
        }
        return Color(red: Double((number >> 16) & 255) / 255,
                     green: Double((number >> 8) & 255) / 255,
                     blue: Double(number & 255) / 255)
    }

    static var palette: IMUNPalette {
        // All UI accents are neutral; meaningful warning and success colors
        // may still appear in medical/training status indicators.
        IMUNPalette(
            canvas: resolvedColor("131516"),   // wilderness charcoal
            surface: resolvedColor("1E2122"),  // slate stone
            raised: resolvedColor("2A2D2D"),   // carved graphite
            outline: resolvedColor("6E7372").opacity(0.52),
            ink: resolvedColor("F0EEE9"),      // limestone parchment
            secondary: resolvedColor("A4A6A3"), // weathered silver
            accent: resolvedColor("D8D3C7"),   // sandstone silver
            supporting: resolvedColor("B9B7B0"))
    }

    /// Compatibility with older cloud clients. No changeable theme leaves the
    /// phone, and incoming legacy theme payloads are not applied.
    static func cloudDesignPayload() -> [String: Any] {
        ["version": 2, "identity": "selah-stone"]
    }
    static func applyCloudDesign(_ data: [String: Any]) -> Bool {
        false
    }

    static var onAccent: Color { resolvedColor("17191A") }
}

/// Supports genuinely different panel silhouettes across every feature.
struct IMUNPanelShape: Shape {
    var shape: String = IMUNStyle.cardShape
    var corner: CGFloat = IMUNStyle.radius
    func path(in rect: CGRect) -> Path {
        let r = min(corner, min(rect.width, rect.height) / 2)
        switch shape {
        case "square":
            return Path(roundedRect: rect, cornerRadius: 2)
        case "pill":
            return Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height)/2)
        case "chamfered":
            let cut = min(max(r, 12), min(rect.width, rect.height)/5)
            var p = Path()
            p.move(to: CGPoint(x: rect.minX+cut,y: rect.minY))
            p.addLine(to: CGPoint(x:rect.maxX-cut,y:rect.minY))
            p.addLine(to: CGPoint(x:rect.maxX,y:rect.minY+cut))
            p.addLine(to: CGPoint(x:rect.maxX,y:rect.maxY-cut))
            p.addLine(to: CGPoint(x:rect.maxX-cut,y:rect.maxY))
            p.addLine(to: CGPoint(x:rect.minX+cut,y:rect.maxY))
            p.addLine(to: CGPoint(x:rect.minX,y:rect.maxY-cut))
            p.addLine(to: CGPoint(x:rect.minX,y:rect.minY+cut))
            p.closeSubpath()
            return p
        case "asymmetric":
            return UnevenRoundedRectangle(
                topLeadingRadius: min(r*1.45, rect.height/2),
                bottomLeadingRadius: 3,
                bottomTrailingRadius: min(r*1.25,rect.height/2),
                topTrailingRadius: 4
            ).path(in: rect)
        default:
            return Path(roundedRect: rect, cornerRadius: r)
        }
    }
}

/// Content-first page backdrop. Theme patterns are reserved for intentional
/// artwork or identity surfaces, not repeated behind charts and controls.
struct IMUNBackdrop: View {
    var body: some View {
        IMUNStyle.palette.canvas
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Content is entirely independent from appearance. Scripture is opt-in and
/// only references are shown here; no unlicensed ESV/LSB text is embedded.
enum IMUNMotivation {
    static var source: String {
        UserDefaults.standard.string(forKey: "hcMotivationSource") ?? "off"
    }
    static var translation: String {
        UserDefaults.standard.string(forKey: "hcMotivationTranslation") ?? "ESV"
    }
    static var tone: String {
        UserDefaults.standard.string(forKey: "hcMotivationTone") ?? "quiet"
    }
    static var custom: String {
        UserDefaults.standard.string(forKey: "hcMotivationCustom") ?? ""
    }
    static var line: String? {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        switch source {
        case "original", "performance":
            // Content choices and tone are independent of the visual theme.
            // Distinct voice sets make the tone picker an actual preference,
            // not a future-looking setting that changes nothing.
            let quiet = source == "original" ? [
                "The standard is built in the hours nobody observes.",
                "You can be tired and still choose precision.",
                "Let preparation remove the need for bravado.",
                "The ordinary session is where trust in yourself develops.",
                "Patience is a skill you practice under resistance.",
                "Progress can be real before it is visible.",
                "Return to the work; not every day needs a verdict."
            ] : [
                "Good training leaves evidence, not theatrics.",
                "Recovery is part of the workload, not its opposite.",
                "One session is a data point. Your habits are the trend.",
                "Build capacity deliberately; don't chase noise.",
                "Repeat the useful work before adding more."
            ]
            let direct = source == "original" ? [
                "Keep the appointment you made with yourself.",
                "Finish the task before negotiating with your mood.",
                "Set the standard. Meet it again tomorrow.",
                "Take the harder useful action.",
                "Don't confuse activity with finished work.",
                "Do what the plan calls for, not what feels impressive.",
                "Make the next decision count."
            ] : [
                "Hit the target. Record the result. Adjust.",
                "Hold the easy pace when the plan says easy.",
                "Train the weakness you keep noticing.",
                "Protect the next session from today's ego.",
                "Control the rep before increasing the load.",
                "Run the assigned interval—not a faster imitation."
            ]
            let rigorous = source == "original" ? [
                "Consistency is a system of decisions, not a personality trait.",
                "An unmeasured promise is not an executed plan.",
                "Difficulty is information. Respond with preparation.",
                "Attention is a resource; allocate it to the task.",
                "Your method should survive an unmotivated day.",
                "Deliberate effort compounds when the process is repeatable."
            ] : [
                "Separate adaptation from fatigue before adding volume.",
                "Maintain the prescribed intensity to control training load.",
                "Trend the work over weeks; don't overread one session.",
                "Record what happened, not what you hoped happened.",
                "Progress the stimulus only when execution stays stable.",
                "Design training you can recover from and repeat."
            ]
            let options: [String]
            switch tone {
            case "direct": options = direct
            case "rigorous": options = rigorous
            default: options = quiet
            }
            return options[day % options.count]
        case "scripture":
            // ESV and LSB are referenced, not reproduced without a license.
            let references = [
                "1 Corinthians 9:24–27", "Hebrews 12:1–2",
                "Colossians 3:23", "James 1:12", "Proverbs 16:3",
                "2 Timothy 2:3–6", "Galatians 6:9", "Proverbs 24:10",
                "1 Peter 5:8", "Psalm 90:12", "Ecclesiastes 9:10",
                "Romans 5:3–5", "Philippians 3:13–14", "Proverbs 13:4"
            ]
            return references[day % references.count] + " · " + translation + " reference"
        case "custom":
            let text = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        default:
            return nil
        }
    }
}


// MARK: - IsAIah identity
// Deliberately fixed, like the IMUN app icon. Surrounding UI follows the
// active design preset; the mark itself is always cream, crimson and graphite.
enum IMUNIsaiahBrand {
    static let cream = Color(red: 0.97, green: 0.965, blue: 0.95)
    static let crimson = Color(red: 0.77, green: 0.035, blue: 0.22)
    static let graphite = Color(red: 0.045, green: 0.05, blue: 0.075)
}

// Exact shape-traced rendition of the original approved Option C artwork.
// Maintains the IMUN family palette at every theme and display scale.
// The contours below are simplified vector outlines of the selected design.
private enum IMUNIsaiahArtworkData {
    static let markWhite = """
377,284 374,281 360,283 358,324 343,344 326,352 286,352 282,356 283,368 331,369 356,358 366,348 375,330|48,283 49,329 55,343 67,357 93,369 140,367 140,354 137,352 97,352 82,345 72,335 65,320 64,283|275,201 275,235 230,234 255,200|307,178 300,171 286,166 251,167 236,174 137,292 188,293 205,271 277,271 281,293 333,293 313,195|181,167 134,168 86,293 131,292|286,56 287,72 328,73 338,77 351,88 360,107 360,144 362,147 374,147 377,144 377,104 373,88 363,72 347,60 335,56|139,56 90,56 64,70 54,83 48,100 48,145 64,145 65,105 69,95 81,81 102,72 139,72
"""
    static let markRed = "177,148 253,147 298,105 222,106"
    static let fullWhite = """
977,157 968,156 967,178 959,188 950,193 929,193 927,201 953,202 966,196 976,181|804,156 804,181 814,195 827,202 852,201 851,193 830,193 822,189 813,176 812,156|486,162 488,155 494,152 552,153 548,163 542,166 492,166|923,113 923,131 900,131 913,113|940,101 929,95 911,95 903,99 851,161 877,162 886,150 924,150 926,162 954,162|874,95 849,96 824,162 847,161|483,95 476,118 556,118 562,121 562,128 560,131 485,131 471,135 458,145 451,158 450,169 454,181 471,190 573,189 595,125 596,114 592,104 585,98 573,94|88,187 192,190 212,183 223,172 230,156 230,144 223,135 204,128 148,128 145,123 153,117 234,117 244,96 143,94 126,100 116,108 109,122 108,135 114,144 135,152 190,152 194,158 186,164 100,163 96,165|626,62 585,189 621,188 643,122 695,122 701,125 702,134 683,188 721,190 741,132 742,118 737,105 730,98 718,94 652,94 661,62|115,59 70,60 27,190 71,188|929,37 930,45 951,46 963,54 968,64 968,83 975,85 977,62 970,45 955,37|852,37 826,37 812,44 804,60 804,84 812,84 813,63 821,50 832,45 852,45
"""
    static let fullRed = """
346,108 344,143 298,142 323,110 327,107|381,90 373,82 361,77 325,78 306,85 286,104 221,188 262,190 278,169 343,169 344,190 384,190 383,98|469,77 426,78 392,190 430,189|872,85 912,85 935,63 895,63|365,63 440,62 485,24 411,24
"""
}

private struct IMUNIsaiahArtworkLayer: Shape {
    let contours: String
    let designWidth: CGFloat
    let designHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var result = Path()
        for raw in contours.split(separator: "|") {
            let points = raw.split(whereSeparator: { $0 == " " || $0 == "\n" })
                .compactMap { pair -> CGPoint? in
                    let parts = pair.split(separator: ",")
                    guard parts.count == 2,
                          let x = Double(parts[0]),
                          let y = Double(parts[1]) else { return nil }
                    return CGPoint(x: rect.minX + CGFloat(x) * rect.width / designWidth,
                                   y: rect.minY + CGFloat(y) * rect.height / designHeight)
                }
            guard let first = points.first else { continue }
            result.move(to: first)
            for point in points.dropFirst() { result.addLine(to: point) }
            result.closeSubpath()
        }
        return result
    }
}

struct IMUNIsaiahArtwork: View {
    enum Layout { case full, mark }
    let layout: Layout

    private var width: CGFloat { layout == .full ? 1000 : 420 }
    private var height: CGFloat { layout == .full ? 211 : 385 }
    private var cream: String {
        layout == .full ? IMUNIsaiahArtworkData.fullWhite : IMUNIsaiahArtworkData.markWhite
    }
    private var red: String {
        layout == .full ? IMUNIsaiahArtworkData.fullRed : IMUNIsaiahArtworkData.markRed
    }

    var body: some View {
        ZStack {
            IMUNIsaiahBrand.graphite
            IMUNIsaiahArtworkLayer(contours: cream, designWidth: width, designHeight: height)
                .fill(IMUNIsaiahBrand.cream, style: FillStyle(eoFill: true))
            IMUNIsaiahArtworkLayer(contours: red, designWidth: width, designHeight: height)
                .fill(IMUNIsaiahBrand.crimson, style: FillStyle(eoFill: true))
        }
        .aspectRatio(width / height, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("IsAIah")
    }
}

struct IMUNIsaiahMark: View {
    var size: CGFloat = 48
    var body: some View {
        IMUNIsaiahArtwork(layout: .mark)
            .frame(width: size, height: size)
    }
}

struct IMUNIsaiahWordmark: View {
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: 0) {
            Text("Is").italic().tracking(-size * 0.035)
                .foregroundStyle(IMUNIsaiahBrand.cream)
            Text("AI").italic().tracking(-size * 0.035)
                .foregroundStyle(IMUNIsaiahBrand.crimson)
            Text("ah").italic().tracking(-size * 0.035)
                .foregroundStyle(IMUNIsaiahBrand.cream)
        }
        .font(.system(size: size, weight: .heavy, design: .rounded))
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("IsAIah")
    }
}


// MARK: - IsAIah floating access
// The approved IA mark is unchanged; only its theme-aware frame glows.
struct IMUNIsaiahLauncherButton: View {
    let glow: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(IMUNIsaiahBrand.graphite)

                // An illuminated outline rather than a solid accent block.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(glow.opacity(0.27), lineWidth: 5)
                    .blur(radius: 6)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(glow.opacity(0.86), lineWidth: 1.3)

                IMUNIsaiahMark(size: 48)
            }
            .frame(width: 62, height: 62)
            .shadow(color: glow.opacity(0.32), radius: 13)
            .shadow(color: .black.opacity(0.23), radius: 8, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(IMUNIsaiahLauncherPressStyle())
        .accessibilityLabel("Ask IsAIah about this screen")
        .accessibilityHint("Open your contextual assistant")
    }
}

private struct IMUNIsaiahLauncherPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
