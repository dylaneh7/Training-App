import SwiftUI

// imun: restrained native typography, subtle graphite surfaces and a single accent.
enum HCDesign {
    static let canvas = Color(red: 0.035, green: 0.055, blue: 0.082)
    static let card = Color(red: 0.072, green: 0.098, blue: 0.132)
    static let raised = Color(red: 0.107, green: 0.137, blue: 0.171)
    static let outline = Color(red: 0.18, green: 0.22, blue: 0.26)
    static let ink = Color(red: 0.96, green: 0.97, blue: 0.96)
    static let secondary = Color(red: 0.60, green: 0.66, blue: 0.70)
    // Default: Crimson + White. Users can change this in Coach → Appearance.
    static var style: String {
        UserDefaults.standard.string(forKey: "hcAccentStyle") ?? "crimson"
    }
    static var electric: Color {
        switch style {
        case "lime": return Color(red: 0.76, green: 0.98, blue: 0.43)
        case "aqua": return Color(red: 0.41, green: 0.85, blue: 0.82)
        case "white": return .white
        default: return Color(red: 0.83, green: 0.20, blue: 0.31) // crimson
        }
    }
    static var onAccent: Color {
        style == "crimson" ? .white : canvas
    }
    static var aqua: Color {
        switch style {
        case "crimson": return .white
        case "white": return Color(red: 0.83, green: 0.88, blue: 0.94)
        default: return Color(red: 0.41, green: 0.85, blue: 0.82)
        }
    }
    static let amber = Color(red: 1.0, green: 0.73, blue: 0.39)

    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func metric(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }
    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}

struct HCAppBackground: View {
    var body: some View {
        ZStack {
            HCDesign.canvas.ignoresSafeArea()
            RadialGradient(colors: [HCDesign.aqua.opacity(0.095), .clear],
                           center: .topTrailing, startRadius: 15, endRadius: 390)
                .ignoresSafeArea()
        }
        .allowsHitTesting(false)
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
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [HCDesign.raised.opacity(0.80),
                                     HCDesign.card],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder((accent ?? HCDesign.outline).opacity(accent == nil ? 0.7 : 0.45),
                                  lineWidth: 1)
            }
    }
}

struct HCSectionTitle: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(HCDesign.label(11))
                .tracking(2.2)
                .foregroundStyle(HCDesign.secondary)
            Spacer()
            if let detail {
                Text(detail).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HCDesign.secondary)
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
                .stroke(tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.17), radius: 8)
            VStack(spacing: 3) {
                Text(value)
                    .font(HCDesign.metric(23))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .foregroundStyle(HCDesign.ink)
                Text(subtitle.uppercased())
                    .font(HCDesign.label(9))
                    .tracking(1.1)
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
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .opacity(0.56)
            }
            .foregroundStyle(tint == HCDesign.electric ? HCDesign.onAccent : HCDesign.canvas)
            .padding(.horizontal, 18)
            .frame(height: 55)
            .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .background(HCDesign.raised, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(HCDesign.outline.opacity(0.75)))
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
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

func hcDuration(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(seconds))
    return String(format: "%02d:%02d", value / 60, value % 60)
}
