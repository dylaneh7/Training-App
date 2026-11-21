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
        .system(size: size, weight: .medium, design: .default)
    }
}

struct HCAppBackground: View {
    var body: some View {
        IMUNBackdrop()
    }
}

struct HCCard<Content: View>: View {
    // Accent remains a source/API parameter for existing callers, but a card
    // should not be brightly bordered merely because it contains a statistic.
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
                IMUNPanelShape(corner: min(IMUNStyle.radius, 14))
                    .fill(HCDesign.card)
            }
            .overlay {
                IMUNPanelShape(corner: min(IMUNStyle.radius, 14))
                    .stroke(HCDesign.outline.opacity(0.43), lineWidth: 1)
            }
    }
}

// Premium editorial hero with atmospheric gradient, fine-line geometry and
// genuinely live content. One component governs every major destination.
// Editorial page introduction. No decorative concentric circles, fake
// telemetry or colored background gradients compete with measured data.
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
        VStack(alignment: .leading, spacing: 14) {
            Text(eyebrow.uppercased())
                .font(HCDesign.label(10))
                .tracking(1.7)
                .foregroundStyle(HCDesign.secondary)
            Text(title)
                .font(HCDesign.display(32))
                .tracking(-0.9)
                .foregroundStyle(HCDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(HCDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(HCDesign.outline.opacity(0.5))
                .frame(height: 1)
            content
        }
        .padding(21)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HCDesign.card,
                    in: IMUNPanelShape(corner: min(IMUNStyle.radius, 14)))
        .overlay {
            IMUNPanelShape(corner: min(IMUNStyle.radius, 14))
                .stroke(HCDesign.outline.opacity(0.4), lineWidth: 1)
        }
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
/// Calm hierarchy throughout the app. Theme differences live in the
/// palette, editorial type and dedicated motif surfaces—not repeated icons
/// before every heading.
struct HCSectionTitle: View {
    let title: String
    var detail: String? = nil
    private let presetName = "heritage"

    private var isEditorial: Bool {
        presetName == "heritage" || presetName == "atelier"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold,
                                  design: isEditorial ? .serif : .default))
                    .foregroundStyle(HCDesign.ink)
                    .tracking(-0.3)
                Spacer(minLength: 6)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(HCDesign.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
            }
            if isEditorial {
                Rectangle()
                    .fill(HCDesign.outline.opacity(0.42))
                    .frame(height: 1)
            }
        }
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
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint == HCDesign.electric ?
                             HCDesign.onAccent : HCDesign.canvas)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background(tint, in: IMUNPanelShape(
                shape: IMUNStyle.buttonShape, corner: 12))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HCDesign.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 43)
                .padding(.horizontal, 9)
                .background(HCDesign.card, in: IMUNPanelShape(
                    shape: IMUNStyle.buttonShape, corner: 11))
                .overlay {
                    IMUNPanelShape(shape: IMUNStyle.buttonShape, corner: 11)
                        .stroke(HCDesign.outline.opacity(0.6), lineWidth: 1)
                }
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

/// Quiet skeleton for the very first data load. No repeating shimmer or
/// animated gradients while scrolling; the real metric cards replace it.
struct IMUNLoadingPlaceholder: View {
    var lines: Int = 3
    var height: CGFloat = 108

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(0..<max(1, lines), id: \.self) { index in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(HCDesign.raised)
                    .frame(height: index == 0 ? 14 : 11)
                    .padding(.trailing, index.isMultiple(of: 2) ? 35 : 85)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .center)
        .background(HCDesign.card,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityLabel("Loading measurements")
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
