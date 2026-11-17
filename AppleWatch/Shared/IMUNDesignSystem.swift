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
enum IMUNStyle {
    private static var prefs: UserDefaults { .standard }
    static var preset: IMUNPreset {
        IMUNPreset(rawValue: prefs.string(forKey: "hcDesignPreset") ?? "") ?? .techno
    }
    static var appearanceMode: String {
        #if os(watchOS)
        // watchOS uses its own dark presentation even when iPhone is light.
        return "dark"
        #else
        return prefs.string(forKey: "hcDesignMode") ?? "dark"
        #endif
    }
    static var customPalette: Bool { prefs.bool(forKey: "hcDesignCustomPalette") }
    static var customGeometry: Bool { prefs.bool(forKey: "hcDesignCustomGeometry") }
    static var cardShape: String {
        customGeometry ? (prefs.string(forKey: "hcDesignShape") ?? "rounded") : preset.defaultShape
    }
    static var font: String {
        customGeometry ? (prefs.string(forKey: "hcDesignFont") ?? "standard") : preset.defaultFont
    }
    static var buttonShape: String {
        customGeometry ? (prefs.string(forKey: "hcDesignButtonShape") ?? "rounded") : preset.defaultShape
    }
    static var density: String {
        customGeometry ? (prefs.string(forKey: "hcDesignDensity") ?? "balanced") : preset.defaultDensity
    }
    static var motif: String {
        customGeometry ? (prefs.string(forKey: "hcDesignMotif") ?? "none") : preset.defaultMotif
    }
    static var navigation: String {
        customGeometry ? (prefs.string(forKey: "hcDesignNavigation") ?? "standard") :
            (preset == .rally ? "sport" : (preset == .atelier ? "editorial" : "standard"))
    }
    static var progressStyle: String {
        customGeometry ? (prefs.string(forKey: "hcDesignProgress") ?? "ring") :
            (preset == .rally || preset == .techno ? "segmented" : "ring")
    }
    static var animationsEnabled: Bool {
        !prefs.bool(forKey: "hcDesignReduceMotion")
    }
    static var preferredScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    static var padding: CGFloat {
        switch density {
        case "compact": return 13
        case "airy": return 23
        default: return 18
        }
    }
    static var radius: CGFloat {
        switch cardShape {
        case "square": return 2
        case "pill": return 32
        case "chamfered": return 10
        default: return 21
        }
    }
    static var headingDesign: Font.Design {
        switch font {
        case "serif": return .serif
        case "rounded": return .rounded
        case "monospaced": return .monospaced
        default: return .default
        }
    }

    static func resolvedColor(_ hex: String) -> Color {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let number = UInt64(clean, radix: 16) else { return .white }
        return Color(red: Double((number >> 16) & 255)/255,
                     green: Double((number >> 8) & 255)/255,
                     blue: Double(number & 255)/255)
    }
    #if os(iOS)
    private static func uiColor(_ hex: String) -> UIColor {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let n = UInt64(clean, radix: 16) ?? 0xFFFFFF
        return UIColor(red: CGFloat((n >> 16) & 255)/255,
                       green: CGFloat((n >> 8) & 255)/255,
                       blue: CGFloat(n & 255)/255, alpha: 1)
    }
    #endif
    private static func adaptive(light: String, dark: String) -> Color {
        switch appearanceMode {
        case "light": return resolvedColor(light)
        case "system":
            #if os(iOS)
            return Color(uiColor: UIColor { traits in
                uiColor(traits.userInterfaceStyle == .light ? light : dark)
            })
            #else
            return resolvedColor(dark) // watchOS interface is dark by design.
            #endif
        default: return resolvedColor(dark)
        }
    }
    static var palette: IMUNPalette {
        let p = preset
        let background = customPalette
            ? resolvedColor(prefs.string(forKey: "hcDesignBackgroundHex") ?? p.darkBackground)
            : adaptive(light: p.lightBackground, dark: p.darkBackground)
        let surface = customPalette
            ? resolvedColor(prefs.string(forKey: "hcDesignSurfaceHex") ?? "243332")
            : adaptive(light: "FFFFFF", dark: p.darkSurface)
        let raised = customPalette ? surface.opacity(0.94) :
            adaptive(light: "E6E2D9", dark: p.darkSurface)
        let ink = customPalette
            ? resolvedColor(prefs.string(forKey: "hcDesignTextHex") ?? "F4F5F2")
            : adaptive(light: "222727", dark: "F6F3E9")
        let secondary = customPalette ? ink.opacity(0.70) :
            adaptive(light: "616968", dark: "A9B0AD")
        let accent = customPalette
            ? resolvedColor(prefs.string(forKey: "hcDesignAccentHex") ?? p.accent)
            : resolvedColor(p.accent)
        return IMUNPalette(canvas: background, surface: surface,
            raised: raised, outline: ink.opacity(0.20), ink: ink,
            secondary: secondary, accent: accent,
            supporting: resolvedColor(p.accentTwo))
    }
    /// Small, explicitly whitelisted appearance snapshot. No workout data,
    /// HealthKit values or credentials are ever part of the cloud design row.
    private static let designStrings: [String] = [
        "hcDesignPreset", "hcDesignMode", "hcDesignAccentHex",
        "hcDesignBackgroundHex", "hcDesignSurfaceHex", "hcDesignTextHex",
        "hcDesignShape", "hcDesignButtonShape", "hcDesignFont",
        "hcDesignDensity", "hcDesignMotif", "hcDesignNavigation",
        "hcDesignProgress"
    ]
    private static let designFlags: [String] = [
        "hcDesignCustomPalette", "hcDesignCustomGeometry",
        "hcDesignReduceMotion"
    ]

    static func cloudDesignPayload() -> [String: Any] {
        var result: [String: Any] = [
            "version": 1,
            "watchSyncEnabled": prefs.bool(forKey: "hcDesignWatchSyncEnabled"),
            "hcDesignPreset": preset.rawValue
        ]
        for key in designStrings {
            if let value = prefs.string(forKey: key), value.count <= 40 {
                result[key] = value
            }
        }
        for key in designFlags {
            result[key] = prefs.bool(forKey: key)
        }
        return result
    }

    static func applyCloudDesign(_ data: [String: Any]) -> Bool {
        guard data["version"] as? Int == 1,
              data["watchSyncEnabled"] as? Bool == true,
              let name = data["hcDesignPreset"] as? String,
              IMUNPreset(rawValue: name) != nil else { return false }
        for key in designStrings {
            guard let value = data[key] as? String,
                  !value.isEmpty, value.count <= 40 else { continue }
            if key.hasSuffix("Hex") &&
               (value.count != 6 || UInt64(value, radix: 16) == nil) { continue }
            prefs.set(value, forKey: key)
        }
        for key in designFlags {
            if let value = data[key] as? Bool { prefs.set(value, forKey: key) }
        }
        prefs.set(name, forKey: "hcDesignPreset")
        return true
    }

    static var onAccent: Color {
        // Contrast-aware foreground for the preset or athlete-selected accent.
        // 0.179 is the relative-luminance crossover for black vs. white text.
        let hex = customPalette
            ? (prefs.string(forKey: "hcDesignAccentHex") ?? preset.accent)
            : preset.accent
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let number = UInt64(clean, radix: 16) ?? 0xFFFFFF
        let channels = [Double((number >> 16) & 255) / 255,
                        Double((number >> 8) & 255) / 255,
                        Double(number & 255) / 255]
        let linear = channels.map { v in
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let luminance = linear[0] * 0.2126 + linear[1] * 0.7152 +
                        linear[2] * 0.0722
        return luminance > 0.179 ? resolvedColor("0B1519") : .white
    }
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

/// An original, compact "IA" precision-frame mark. Vector geometry remains
/// crisp in a floating iPhone launcher and in a watchOS daily summary.
struct IMUNIsaiahMark: View {
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.20, style: .continuous)
                .fill(IMUNIsaiahBrand.graphite)
            Path { p in
                let inset = size * 0.14
                let length = size * 0.19
                let far = size - inset
                p.move(to: CGPoint(x: inset + length, y: inset))
                p.addLine(to: CGPoint(x: inset, y: inset))
                p.addLine(to: CGPoint(x: inset, y: inset + length))
                p.move(to: CGPoint(x: far - length, y: inset))
                p.addLine(to: CGPoint(x: far, y: inset))
                p.addLine(to: CGPoint(x: far, y: inset + length))
                p.move(to: CGPoint(x: inset, y: far - length))
                p.addLine(to: CGPoint(x: inset, y: far))
                p.addLine(to: CGPoint(x: inset + length, y: far))
                p.move(to: CGPoint(x: far, y: far - length))
                p.addLine(to: CGPoint(x: far, y: far))
                p.addLine(to: CGPoint(x: far - length, y: far))
            }
            .stroke(IMUNIsaiahBrand.cream, style: StrokeStyle(
                lineWidth: max(1.4, size * 0.04), lineCap: .round, lineJoin: .round))
            HStack(spacing: -size * 0.045) {
                Text("I").italic().foregroundStyle(IMUNIsaiahBrand.cream)
                Text("A").italic().foregroundStyle(IMUNIsaiahBrand.cream)
            }
            .font(.system(size: size * 0.43, weight: .black, design: .rounded))
            .offset(y: size * 0.055)
            Path { p in
                p.move(to: CGPoint(x: size * 0.50, y: size * 0.20))
                p.addLine(to: CGPoint(x: size * 0.76, y: size * 0.20))
                p.addLine(to: CGPoint(x: size * 0.68, y: size * 0.30))
                p.addLine(to: CGPoint(x: size * 0.43, y: size * 0.30))
                p.closeSubpath()
            }
            .fill(IMUNIsaiahBrand.crimson)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("IsAIah")
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
