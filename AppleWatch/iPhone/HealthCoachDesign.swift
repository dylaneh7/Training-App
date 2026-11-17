import SwiftUI

// imun: restrained native typography, subtle graphite surfaces and a single accent.
enum HCDesign {
    static var canvas: Color { IMUNStyle.palette.canvas }
    static var card: Color { IMUNStyle.palette.surface }
    static var raised: Color { IMUNStyle.palette.raised }
    static var outline: Color { IMUNStyle.palette.outline }
    static var ink: Color { IMUNStyle.palette.ink }
    static var secondary: Color { IMUNStyle.palette.secondary }
    static var electric: Color { IMUNStyle.palette.accent }
    static var aqua: Color { IMUNStyle.palette.supporting }
    static var onAccent: Color { IMUNStyle.onAccent }
    static var amber: Color { Color(red: 1.0, green: 0.73, blue: 0.39) }
    static var good: Color { Color(red: 0.36, green: 0.83, blue: 0.68) }
    static var caution: Color { Color(red: 0.99, green: 0.76, blue: 0.42) }
    static var danger: Color { Color(red: 1.0, green: 0.46, blue: 0.48) }

    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .semibold, design: IMUNStyle.headingDesign)
    }
    static func metric(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold,
                design: IMUNStyle.headingDesign).monospacedDigit()
    }
    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: IMUNStyle.headingDesign)
    }
}

struct HCAppBackground: View {
    var body: some View {
        IMUNBackdrop()
    }
}

struct HCCard<Content: View>: View {
    var accent: Color? = nil
    let content: Content

    init(accent: Color? = nil, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .padding(IMUNStyle.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                IMUNPanelShape()
                    .fill(LinearGradient(
                        colors: [HCDesign.raised, HCDesign.card],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                IMUNPanelShape()
                    .stroke((accent ?? HCDesign.outline).opacity(accent == nil ? 0.7 : 0.6),
                            lineWidth: 1)
            }
    }
}


// Premium editorial hero with atmospheric gradient, fine-line geometry and
// genuinely live content. One component governs every major destination.
struct HCPremiumHero<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var icon: String = "sparkles"
    var tint: Color = HCDesign.electric
    let content: Content

    init(eyebrow: String, title: String, subtitle: String,
         icon: String = "sparkles", tint: Color = HCDesign.electric,
         @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            IMUNPanelShape()
                .fill(LinearGradient(colors: [
                    tint.opacity(0.24), HCDesign.raised, HCDesign.card
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .strokeBorder(tint.opacity(0.16), lineWidth: 1)
                .frame(width: 200, height: 200)
                .offset(x: 80, y: -110)
            Circle()
                .strokeBorder(tint.opacity(0.10), lineWidth: 17)
                .frame(width: 138, height: 138)
                .offset(x: 65, y: -85)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 9) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                    Text(eyebrow.uppercased())
                        .tracking(2.0)
                    Spacer()
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundStyle(HCDesign.ink.opacity(0.32))
                }
                .font(HCDesign.label(10))
                .foregroundStyle(tint)
                Text(title)
                    .font(HCDesign.display(31))
                    .tracking(-1.1)
                    .foregroundStyle(HCDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HCDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                content
            }
            .padding(21)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(IMUNPanelShape())
        .overlay(IMUNPanelShape().stroke(tint.opacity(0.32), lineWidth: 1))
    }
}

// A legible status chip for meaningful source-attributed observations.
struct HCStatusLine: View {
    let text: String
    let symbol: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
    }
}

struct HCMetricGauge: View {
    let title: String
    let value: String
    let progress: Double
    let detail: String
    let tint: Color
    var symbol: String = "waveform.path"

    var body: some View {
        // Large units such as "breaths/min" must not be clipped inside a
        // 98-pt gauge. Keep the measured number prominent; put its unit below.
        let words = value.split(separator: " ", maxSplits: 1).map(String.init)
        let number = words.first ?? value
        let unit = words.count > 1 ? words[1] : title
        return HStack(spacing: 13) {
            HCProgressRing(progress: progress, value: number,
                           subtitle: unit, tint: tint, diameter: 98)
            VStack(alignment: .leading, spacing: 9) {
                Label(title.uppercased(), systemImage: symbol)
                    .font(HCDesign.label(10))
                    .tracking(0.8)
                    .foregroundStyle(tint)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HCDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Small theme-specific section identity used throughout Training, Health,
/// Progress and Coach. No single racing/technology motif leaks across themes.
struct HCSectionTitle: View {
    let title: String
    var detail: String? = nil
    @AppStorage("hcDesignPreset") private var presetName = "techno"
    private var preset: IMUNPreset { IMUNPreset(rawValue: presetName) ?? .techno }

    @ViewBuilder
    private var marker: some View {
        switch preset {
        case .heritage:
            Image(systemName: "leaf").font(.system(size: 12, weight: .semibold))
        case .retro:
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Rectangle().frame(width: i == 1 ? 7 : 4, height: 7)
                }
            }
        case .techno:
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 12, weight: .bold))
        case .coast:
            Image(systemName: "water.waves")
                .font(.system(size: 12, weight: .medium))
        case .fieldNotes:
            Image(systemName: "map")
                .font(.system(size: 12, weight: .medium))
        case .discipline:
            Rectangle().frame(width: 3, height: 17)
        case .atelier:
            Image(systemName: "textformat")
                .font(.system(size: 13, weight: .light))
        case .rally:
            Image(systemName: "flag.checkered")
                .font(.system(size: 12, weight: .bold))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 9) {
                marker
                    .foregroundStyle(HCDesign.aqua)
                    .frame(width: 17)
                    .accessibilityHidden(true)
                Text(title.uppercased())
                    .font(HCDesign.label(11))
                    .tracking(preset == .atelier ? 2.6 : 2)
                    .foregroundStyle(HCDesign.secondary)
                Spacer(minLength: 5)
                if let detail {
                    Text(detail).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HCDesign.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
            // Editorial sporting and archival identities use fine rules;
            // technology/retro/field styles keep the more compact heading.
            if preset == .heritage || preset == .atelier {
                Rectangle().fill(HCDesign.outline.opacity(0.7))
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, 2)
    }
}

struct HCAccentTag: View {
    let title: String
    var color: Color = HCDesign.aqua

    var body: some View {
        Text(title.uppercased())
            .font(HCDesign.label(10))
            .tracking(1)
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.19)))
    }
}


// Reusable progress treatment for measured completion, not an inferred health score.
// Recovery readiness will use a separate evidence-based model in a later phase.
struct HCProgressRing: View {
    let progress: Double
    let value: String
    let subtitle: String
    var tint: Color = HCDesign.electric
    var diameter: CGFloat = 112

    private var bounded: Double { min(1, max(0, progress)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(HCDesign.outline, lineWidth: 9)
            Circle()
                .trim(from: 0, to: bounded)
                .stroke(tint, style: StrokeStyle(
                    lineWidth: 9,
                    lineCap: IMUNStyle.progressStyle == "segmented" ? .butt : .round,
                    dash: IMUNStyle.progressStyle == "segmented" ? [10, 5] : []))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.17), radius: 8)
            VStack(spacing: 3) {
                Text(value)
                    .font(HCDesign.metric(23))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .foregroundStyle(HCDesign.ink)
                Text(subtitle.uppercased())
                    .font(HCDesign.label(8))
                    .tracking(0.2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.66)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: diameter - 15)
                    .foregroundStyle(HCDesign.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(subtitle + ": " + value)
    }
}

// Shared label for actionable, source-based trends and sync states.
struct HCInsightChip: View {
    let title: String
    let symbol: String
    var tint: Color = HCDesign.aqua

    var body: some View {
        Label(title, systemImage: symbol)
            .font(HCDesign.label(11))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(tint.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.22)))
    }
}

struct HCMetricBlock: View {
    let label: String
    let value: String
    var tint: Color = HCDesign.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(HCDesign.metric(24))
                .minimumScaleFactor(0.67)
                .lineLimit(1)
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(HCDesign.label(9))
                .tracking(1)
                .foregroundStyle(HCDesign.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HCFilledButton: View {
    let title: String
    let icon: String
    var tint: Color = HCDesign.electric
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: IMUNStyle.headingDesign))
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .opacity(0.56)
            }
            .foregroundStyle(tint == HCDesign.electric ? HCDesign.onAccent : HCDesign.canvas)
            .padding(.horizontal, 18)
            .frame(height: 55)
            .background(tint, in: IMUNPanelShape(
                shape: IMUNStyle.buttonShape, corner: 16))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(title)
    }
}

struct HCOutlineButton: View {
    let title: String
    let icon: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(HCDesign.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(HCDesign.raised, in: IMUNPanelShape(
                    shape: IMUNStyle.buttonShape, corner: 14))
                .overlay(IMUNPanelShape(shape: IMUNStyle.buttonShape, corner: 14)
                    .stroke(HCDesign.outline.opacity(0.75)))
        }
        .buttonStyle(.plain)
    }
}

struct HCNumberControl: View {
    let label: String
    let value: String
    var suffix: String = ""
    var decrement: () -> Void
    var increment: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 46, height: 48)
                    .background(HCDesign.raised, in: RoundedRectangle(cornerRadius: 13))
            }
            .accessibilityLabel("Decrease \(label)")
            Spacer(minLength: 0)
            VStack(spacing: 3) {
                Text(label.uppercased())
                    .font(HCDesign.label(9))
                    .tracking(1.4)
                    .foregroundStyle(HCDesign.secondary)
                Text(value + suffix)
                    .font(HCDesign.metric(26))
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 46, height: 48)
                    .background(HCDesign.raised, in: RoundedRectangle(cornerRadius: 13))
            }
            .accessibilityLabel("Increase \(label)")
        }
        .buttonStyle(.plain)
        .foregroundStyle(HCDesign.ink)
    }
}

struct HCSyncStatus: View {
    let pending: Int
    let saving: Bool
    let connected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connected ? (pending == 0 && !saving ? HCDesign.electric : HCDesign.amber) : HCDesign.secondary)
                .frame(width: 7, height: 7)
            Text(!connected ? "OFFLINE ACCOUNT" : saving ? "SAVING PLAN" :
                 pending > 0 ? "\(pending) PENDING UPLOAD" : "ALL SETS SYNCED")
                .font(HCDesign.label(10))
                .tracking(0.6)
                .foregroundStyle(HCDesign.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func hcPage() -> some View {
        self
            .foregroundStyle(HCDesign.ink)
            .background(HCAppBackground())
            .toolbarBackground(HCDesign.canvas, for: .navigationBar)
            .toolbarColorScheme(IMUNStyle.preferredScheme, for: .navigationBar)
    }
}

func hcDuration(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(seconds))
    return String(format: "%02d:%02d", value / 60, value % 60)
}
