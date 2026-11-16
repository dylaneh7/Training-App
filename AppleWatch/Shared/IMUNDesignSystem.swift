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
    // A compact, whitelisted preferences envelope for the user-scoped cloud
    // route. It is separate from strength plans, HealthKit and workout logs.
    private static let cloudStrings = [
        "hcDesignPreset", "hcDesignMode", "hcDesignAccentHex",
        "hcDesignBackgroundHex", "hcDesignSurfaceHex", "hcDesignTextHex",
        "hcDesignShape", "hcDesignButtonShape", "hcDesignFont",
        "hcDesignDensity", "hcDesignMotif", "hcDesignNavigation",
        "hcDesignProgress"
    ]
    private static let cloudFlags = [
        "hcDesignCustomPalette", "hcDesignCustomGeometry",
        "hcDesignReduceMotion"
    ]
    static func cloudPayload() -> [String: Any] {
        var result: [String: Any] = ["version": 1,
            "watchSyncEnabled": prefs.bool(forKey: "hcDesignWatchSyncEnabled"),
            "hcDesignPreset": preset.rawValue]
        for key in cloudStrings {
            if let value = prefs.string(forKey: key) {
                result[key] = String(value.prefix(40))
            }
        }
        for key in cloudFlags {
            result[key] = prefs.bool(forKey: key)
        }
        return result
    }
    static func applyCloudPayload(_ data: [String: Any]) {
        guard data["watchSyncEnabled"] as? Bool == true,
              let name = data["hcDesignPreset"] as? String,
              IMUNPreset(rawValue: name) != nil else { return }
        for key in cloudStrings {
            guard let value = data[key] as? String, !value.isEmpty,
                  value.count <= 40 else { continue }
            if key.hasSuffix("Hex") &&
               (value.count != 6 || UInt64(value, radix: 16) == nil) { continue }
            prefs.set(value, forKey: key)
        }
        for key in cloudFlags {
            if let value = data[key] as? Bool { prefs.set(value, forKey: key) }
        }
        prefs.set(name, forKey: "hcDesignPreset")
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

/// Low-contrast vector motifs: no photos/downloads and no extra permissions.
struct IMUNBackdrop: View {
    var body: some View {
        ZStack {
            IMUNStyle.palette.canvas
            if IMUNStyle.motif == "glow" {
                RadialGradient(colors: [IMUNStyle.palette.accent.opacity(0.20), .clear],
                               center: .topTrailing, startRadius: 10, endRadius: 480)
            } else if IMUNStyle.motif != "none" {
                Canvas { context, size in
                    let motif = IMUNStyle.motif
                    let spacing: CGFloat = motif == "grid" ? 30 : 54
                    let color = IMUNStyle.palette.supporting.opacity(0.11)
                    if motif == "stripes" {
                        for v in stride(from: CGFloat(-size.height), through: size.width, by: spacing) {
                            var line = Path()
                            line.move(to: CGPoint(x:v,y:0))
                            line.addLine(to: CGPoint(x:v+size.height,y:size.height))
                            context.stroke(line, with:.color(color), lineWidth:1)
                        }
                    } else {
                        for x in stride(from: CGFloat(0), through: size.width, by: spacing) {
                            var line = Path()
                            line.move(to: CGPoint(x:x,y:0))
                            line.addLine(to: CGPoint(x:x,y:size.height))
                            context.stroke(line, with:.color(color), lineWidth:0.7)
                        }
                        if motif == "grid" || motif == "contours" {
                            for y in stride(from: CGFloat(0), through: size.height, by: spacing) {
                                var line = Path()
                                line.move(to: CGPoint(x:0,y:y))
                                line.addLine(to: CGPoint(x:size.width,y:y))
                                context.stroke(line, with:.color(color), lineWidth:0.7)
                            }
                        }
                    }
                }
            }
        }
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
        case "original":
            let options = [
                "Preparation is a kind of courage.",
                "Do the work that will still matter tomorrow.",
                "Make your actions match the standard you set.",
                "Consistency compounds quietly.",
                "Progress is earned in the repetitions nobody sees."
            ]
            return options[day % options.count]
        case "performance":
            let options = [
                "Train the process. Measure the result.",
                "The next repetition is the only one you can complete.",
                "Precision first. Effort follows.",
                "Show up prepared. Finish with intent.",
                "Your pace is data, not your identity."
            ]
            return options[day % options.count]
        case "scripture":
            let options = ["1 Corinthians 9:24–27", "Hebrews 12:1–2",
                           "Colossians 3:23", "James 1:12", "Proverbs 16:3"]
            return options[day % options.count] + " · " + translation + " reference"
        case "custom":
            let text = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        default:
            return nil
        }
    }
}
