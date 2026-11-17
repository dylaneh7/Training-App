import SwiftUI

// The interface theme changes how facts are presented, never the facts
// themselves. In particular, a warning count is not a medical readiness score.
private enum IMUNThemeText {
    static func heading(_ theme: IMUNPreset, for area: String) -> String {
        switch theme {
        case .heritage: return area == "recovery" ? "DAILY CONDITION LEDGER" : "THE TRAINING REGISTER"
        case .retro: return area == "recovery" ? "CONDITION SCOREBOARD" : "SESSION SCOREBOARD"
        case .techno: return area == "recovery" ? "SYSTEM DIAGNOSTICS" : "PERFORMANCE TELEMETRY"
        case .coast: return area == "recovery" ? "DAILY TIDE REPORT" : "THE TRAINING CURRENT"
        case .fieldNotes: return area == "recovery" ? "TRAIL CONDITIONS" : "EXPEDITION LOG"
        case .discipline: return area == "recovery" ? "RECOVERY BRIEF" : "EXECUTION REPORT"
        case .atelier: return area == "recovery" ? "THE DAILY HEALTH EDITION" : "THE TRAINING EDITION"
        case .rally: return area == "recovery" ? "PIT WALL / RECOVERY" : "RACE DAY / PROGRESS"
        }
    }

    static func restTitle(_ theme: IMUNPreset) -> String {
        switch theme {
        case .heritage: return "BETWEEN ROUNDS"
        case .retro: return "INTERMISSION"
        case .techno: return "SYSTEM RESET"
        case .coast: return "CATCH YOUR BREATH"
        case .fieldNotes: return "TRAIL REST STOP"
        case .discipline: return "REST INTERVAL"
        case .atelier: return "A MOMENT BETWEEN SETS"
        case .rally: return "PIT STOP"
        }
    }

    static func restSymbol(_ theme: IMUNPreset) -> String {
        switch theme {
        case .heritage: return "shield.lefthalf.filled"
        case .retro: return "stopwatch"
        case .techno: return "waveform.path.ecg"
        case .coast: return "water.waves"
        case .fieldNotes: return "mountain.2"
        case .discipline: return "pause.rectangle.fill"
        case .atelier: return "text.alignleft"
        case .rally: return "wrench.adjustable.fill"
        }
    }
}

/// A lightweight motif that is genuinely different for each theme, shared by
/// the home, history, recovery and Watch screens. There is NO car or race icon
/// outside the Rally case.
struct IMUNThemeEmblem: View {
    @AppStorage("hcDesignPreset") private var presetName = "techno"
    var area: String = "training"
    var compact: Bool = false
    private var theme: IMUNPreset { IMUNPreset(rawValue: presetName) ?? .techno }
    private var accent: Color { IMUNStyle.palette.accent }
    private var muted: Color { IMUNStyle.palette.secondary }
    private var ink: Color { IMUNStyle.palette.ink }

    var body: some View {
        HStack(spacing: compact ? 8 : 13) {
            emblem
                .frame(width: compact ? 29 : 47,
                       height: compact ? 29 : 47)
            VStack(alignment: .leading, spacing: 3) {
                Text(IMUNThemeText.heading(theme, for: area))
                    .font(.system(size: compact ? 9 : 12, weight: .bold,
                                  design: theme == .heritage || theme == .atelier ?
                                    .serif : theme == .retro || theme == .techno ||
                                    theme == .rally ? .monospaced : .default))
                    .tracking(compact ? 0.45 : 1.3)
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                if !compact {
                    Text(theme.tagline)
                        .font(.system(size: 11))
                        .foregroundStyle(muted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 1)
            if !compact {
                Text(theme.title.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(accent)
            }
        }
        .padding(.vertical, compact ? 2 : 7)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var emblem: some View {
        switch theme {
        case .heritage:
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(accent.opacity(0.7), lineWidth: 1.5)
                    .padding(3)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: compact ? 15 : 27, weight: .light))
                    .foregroundStyle(accent)
            }
        case .retro:
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(accent.opacity(0.12))
                Image(systemName: "stopwatch")
                    .font(.system(size: compact ? 19 : 30, weight: .medium))
                    .foregroundStyle(accent)
            }
        case .techno:
            ZStack {
                RoundedRectangle(cornerRadius: 1)
                    .stroke(accent.opacity(0.55), lineWidth: 1)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: compact ? 15 : 25, weight: .medium))
                    .foregroundStyle(accent)
            }
        case .coast:
            Image(systemName: "water.waves")
                .font(.system(size: compact ? 20 : 32, weight: .ultraLight))
                .foregroundStyle(accent)
        case .fieldNotes:
            ZStack {
                Circle().stroke(accent.opacity(0.52), lineWidth: 1)
                Image(systemName: "mountain.2")
                    .font(.system(size: compact ? 17 : 26, weight: .light))
                    .foregroundStyle(accent)
            }
        case .discipline:
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { row in
                    Rectangle()
                        .fill(row == 0 ? accent : muted.opacity(0.45))
                        .frame(height: compact ? 4 : 6)
                }
            }
        case .atelier:
            ZStack {
                Rectangle().fill(accent).frame(width: 2)
                    .offset(x: compact ? -10 : -18)
                Text("i")
                    .font(.system(size: compact ? 26 : 42,
                                  weight: .ultraLight, design: .serif))
                    .italic()
                    .foregroundStyle(accent)
            }
        case .rally:
            ZStack {
                IMUNPanelShape(shape: "chamfered", corner: 9)
                    .stroke(accent, lineWidth: 1.5)
                Image(systemName: "flag.checkered")
                    .font(.system(size: compact ? 16 : 26, weight: .medium))
                    .foregroundStyle(accent)
            }
        }
    }
}

/// Each identity gets its OWN recovery-specific explanation and illustration.
/// These numbers reflect measured signal coverage and flagged comparisons;
/// there is no invented composite recovery, sleep or readiness score.
struct IMUNThemeRecoveryBrief: View {
    @AppStorage("hcDesignPreset") private var presetName = "techno"
    let compared: Int
    let flagged: Int
    let sources: Int
    private var theme: IMUNPreset { IMUNPreset(rawValue: presetName) ?? .techno }
    private var accent: Color { IMUNStyle.palette.accent }
    private var muted: Color { IMUNStyle.palette.secondary }
    private var ink: Color { IMUNStyle.palette.ink }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            IMUNThemeEmblem(area: "recovery")
            switch theme {
            case .rally: rallyBrief
            case .heritage: heritageBrief
            case .retro: retroBrief
            case .techno: technoBrief
            case .coast: coastBrief
            case .fieldNotes: fieldNotesBrief
            case .discipline: disciplineBrief
            case .atelier: atelierBrief
            }
            Text("Source-specific comparisons · not a medical readiness score.")
                .font(.system(size: 10))
                .foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rallyBrief: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 7) {
                Label("PIT CHECK", systemImage: "wrench.adjustable.fill")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                Text("\(flagged) FLAGGED")
                    .font(.system(size: 25, weight: .black, design: .monospaced))
                    .foregroundStyle(ink)
                Text("\(compared) sensor comparisons")
                    .font(.caption).foregroundStyle(muted)
            }
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Image(systemName: "car.side.fill")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(accent)
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Rectangle()
                            .fill(i < min(5, compared) ? accent : muted.opacity(0.2))
                            .frame(width: 9, height: 5)
                    }
                }
                Text("PIT LANE")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(muted)
            }
        }
    }

    private var heritageBrief: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("\(compared)")
                .font(.system(size: 48, weight: .light, design: .serif))
                .foregroundStyle(ink)
            VStack(alignment: .leading, spacing: 5) {
                Text("OBSERVATIONS IN THE LEDGER")
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(accent)
                Rectangle().fill(accent.opacity(0.6)).frame(height: 1)
                Text("\(flagged) outside recent pattern")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(muted)
            }
        }
    }

    private var retroBrief: some View {
        HStack(spacing: 10) {
            retroDigit(title: "CHECKED", value: compared)
            retroDigit(title: "ALERTS", value: flagged)
            retroDigit(title: "INPUTS", value: sources)
        }
    }
    private func retroDigit(title: String, value: Int) -> some View {
        VStack(spacing: 6) {
            Text(String(format: "%02d", value))
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 4))
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var technoBrief: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("SENSORS ONLINE")
                    .foregroundStyle(accent)
                Spacer()
                Text(String(format: "%02d", sources))
                    .foregroundStyle(ink)
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            HStack(spacing: 4) {
                ForEach(0..<18, id: \.self) { i in
                    Rectangle()
                        .fill(i < min(18, compared) ? accent : muted.opacity(0.16))
                        .frame(maxWidth: .infinity)
                        .frame(height: CGFloat((i*3)%9+4))
                }
            }
            Text("\(compared) BASELINE COMPARISONS / \(flagged) OUTSIDE PATTERN")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(muted)
        }
    }

    private var coastBrief: some View {
        HStack(spacing: 14) {
            Image(systemName: "water.waves")
                .font(.system(size: 46, weight: .ultraLight))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR DAILY TIDE")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(accent)
                Text("\(compared) comparisons · \(sources) sources")
                    .font(.system(size: 15, weight: .light, design: .rounded))
                    .foregroundStyle(ink)
                Text("\(flagged) readings outside your usual range")
                    .font(.system(size: 11)).foregroundStyle(muted)
            }
        }
        .padding(.vertical, 7)
    }

    private var fieldNotesBrief: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "mountain.2")
                    .foregroundStyle(accent)
                Text("CONDITIONS ALONG THE ROUTE")
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(ink)
            }
            HStack(spacing: 5) {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(i < min(6, compared) ? accent : muted.opacity(0.25))
                        .frame(width: 9, height: 9)
                    if i != 5 {
                        Rectangle().fill(muted.opacity(0.3)).frame(height: 1)
                    }
                }
            }
            Text("\(compared) observations · \(flagged) conditions worth reviewing")
                .font(.system(size: 12, design: .serif)).foregroundStyle(muted)
        }
    }

    private var disciplineBrief: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(compared)")
                    .font(.system(size: 43, weight: .black, design: .monospaced))
                    .foregroundStyle(ink)
                Text("CHECKED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(muted)
            }
            Rectangle().fill(accent).frame(width: 2, height: 57)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(flagged)")
                    .font(.system(size: 43, weight: .black, design: .monospaced))
                    .foregroundStyle(ink)
                Text("TO REVIEW")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(muted)
            }
            Spacer(minLength: 1)
        }
    }

    private var atelierBrief: some View {
        HStack(alignment: .top, spacing: 16) {
            Rectangle().fill(accent).frame(width: 2, height: 103)
            VStack(alignment: .leading, spacing: 5) {
                Text("The daily condition")
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .foregroundStyle(ink)
                Text("\(compared) comparative readings")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(muted)
                Text("\(flagged) outside recent patterns")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(muted)
            }
        }
    }
}

/// Short rest UI for the Watch. Recovery instructions are themed without
/// modifying rest timestamps or the workout's automatic-advance behavior.
struct IMUNThemeRestHeader: View {
    @AppStorage("hcDesignPreset") private var presetName = "techno"
    private var theme: IMUNPreset { IMUNPreset(rawValue: presetName) ?? .techno }
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: IMUNThemeText.restSymbol(theme))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(IMUNStyle.palette.supporting)
            Text(IMUNThemeText.restTitle(theme))
                .font(.system(size: 11, weight: .semibold,
                              design: IMUNStyle.headingDesign))
                .foregroundStyle(IMUNStyle.palette.supporting)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
