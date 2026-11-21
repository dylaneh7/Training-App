import SwiftUI

/// Training clock presentation. It never manufactures readiness values:
/// elapsed and remaining seconds come from the existing persisted clocks.
/// Every preset gets its own visual treatment, never a copied Rally car.
struct IMUNThemeTimerFace: View {
    private let selectedName = "heritage"
    var seconds: TimeInterval
    var countsDown: Bool = true
    var compact: Bool = false

    private var theme: IMUNPreset {
        .heritage
    }
    private var accent: Color { IMUNStyle.palette.accent }
    private var ink: Color { IMUNStyle.palette.ink }
    private var supporting: Color { IMUNStyle.palette.supporting }
    private var muted: Color { IMUNStyle.palette.secondary }

    private var clock: String {
        let s = Int(max(0, seconds).rounded(.up))
        let h = s / 3600
        return h > 0
            ? String(format: "%d:%02d:%02d", h, (s / 60) % 60, s % 60)
            : String(format: "%02d:%02d", s / 60, s % 60)
    }
    private var title: String {
        if !countsDown { return "WORKING SET · ELAPSED" }
        switch theme {
        case .heritage: return "BETWEEN ROUNDS"
        case .retro: return "INTERMISSION CLOCK"
        case .techno: return "RESET COUNTDOWN"
        case .coast: return "BREATHING ROOM"
        case .fieldNotes: return "TRAIL REST STOP"
        case .discipline: return "REST INTERVAL"
        case .atelier: return "A MOMENT OF REST"
        case .rally: return "PIT STOP TIMER"
        }
    }
    private var symbol: String {
        switch theme {
        case .heritage: return "clock"
        case .retro: return "stopwatch"
        case .techno: return "waveform.path"
        case .coast: return "water.waves"
        case .fieldNotes: return "mountain.2"
        case .discipline: return "timer"
        case .atelier: return "hourglass"
        case .rally: return "wrench.and.screwdriver.fill"
        }
    }
    private var headingDesign: Font.Design {
        switch theme {
        case .heritage, .fieldNotes, .atelier: return .serif
        case .retro, .techno, .discipline, .rally: return .monospaced
        case .coast: return .rounded
        }
    }

    var body: some View {
        HStack(spacing: compact ? 8 : 14) {
            accentMark
                .frame(width: compact ? 27 : 46,
                       height: compact ? 27 : 46)
            VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                Text(title)
                    .font(.system(size: compact ? 9 : 11, weight: .semibold,
                                  design: headingDesign))
                    .tracking(compact ? 0.5 : 1.1)
                    .foregroundStyle(muted)
                    .lineLimit(2)
                Text(clock)
                    .font(.system(size: compact ? 32 : 40, weight: theme == .atelier ? .regular : .bold,
                                  design: headingDesign))
                    .monospacedDigit()
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .foregroundStyle(ink)
            }
            Spacer(minLength: 0)
            if !compact {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .light))
                    .foregroundStyle(supporting)
            }
        }
        .padding(compact ? 8 : 14)
        .background(IMUNStyle.palette.surface,
                    in: IMUNPanelShape(shape: IMUNStyle.cardShape,
                                       corner: compact ? 10 : 16))
        .overlay(IMUNPanelShape(shape: IMUNStyle.cardShape,
                                corner: compact ? 10 : 16)
                 .stroke(accent.opacity(0.38), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + " " + clock)
    }

    @ViewBuilder
    private var accentMark: some View {
        switch theme {
        case .heritage:
            ZStack {
                Circle().stroke(accent, lineWidth: 1.4)
                Image(systemName: "clock")
                    .font(.system(size: compact ? 17 : 26, weight: .light))
                    .foregroundStyle(accent)
            }
        case .retro:
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(accent.opacity(0.15))
                Text("88")
                    .font(.system(size: compact ? 15 : 24,
                                  weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
            }
        case .techno:
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: compact ? 22 : 32))
                .foregroundStyle(accent)
        case .coast:
            Image(systemName: "water.waves")
                .font(.system(size: compact ? 22 : 33, weight: .ultraLight))
                .foregroundStyle(accent)
        case .fieldNotes:
            ZStack {
                Circle().stroke(accent.opacity(0.6), lineWidth: 1)
                Image(systemName: "mountain.2")
                    .font(.system(size: compact ? 17 : 28, weight: .light))
                    .foregroundStyle(accent)
            }
        case .discipline:
            VStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(index == 0 ? accent : muted.opacity(0.24))
                        .frame(height: compact ? 3 : 5)
                }
            }
        case .atelier:
            HStack(spacing: 3) {
                Rectangle().fill(accent).frame(width: 2)
                Image(systemName: "hourglass")
                    .font(.system(size: compact ? 17 : 27, weight: .ultraLight))
                    .foregroundStyle(accent)
            }
        case .rally:
            ZStack {
                IMUNPanelShape(shape: "chamfered", corner: 7)
                    .stroke(accent, lineWidth: 1.5)
                Image(systemName: "wrench.adjustable.fill")
                    .font(.system(size: compact ? 16 : 26))
                    .foregroundStyle(accent)
            }
        }
    }
}
