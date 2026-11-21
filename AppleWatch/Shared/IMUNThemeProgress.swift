import SwiftUI

/// A distinct measurable progress metaphor for every IMUN identity.
/// The value is completion of today's prescribed training sets, never a
/// synthetic recovery/readiness score. Existing Health signals remain separate.
struct IMUNThemeProgressView: View {
    // This view MUST observe the selected preset itself. Reading the
    // UserDefaults-backed IMUNStyle.preset alone does not invalidate SwiftUI
    // when someone switches from Rally to another theme while this page lives.
    private let designPresetName = "heritage"
    private var theme: IMUNPreset {
        .heritage
    }

    let completed: Int
    let planned: Int
    var compact: Bool = false

    private var done: Int { max(0, min(completed, planned)) }
    private var fraction: Double {
        planned > 0 ? Double(done)/Double(planned) : 0
    }
    private var count: String { "\(done)/\(planned)" }
    private var accent: Color { IMUNStyle.palette.accent }
    private var muted: Color { IMUNStyle.palette.secondary }
    private var ink: Color { IMUNStyle.palette.ink }

    var body: some View {
        Group {
            switch theme {
            case .rally: rally
            case .heritage: heritage
            case .retro: retro
            case .techno: techno
            case .coast: coast
            case .fieldNotes: fieldNotes
            case .discipline: discipline
            case .atelier: atelier
            }
        }
        .frame(width: compact ? 104 : nil,
               height: compact ? 97 : 184)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(theme.title) · \(done) of \(planned) planned workout sets completed")
    }

    // The car follows a real fraction of prescribed set completion. This is
    // a workout progress track; the neighboring recovery signals stay factual.
    private var rally: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let radiusX = w * 0.41
            let radiusY = h * 0.35
            let angle = -Double.pi/2 + Double.pi * 2 * fraction
            ZStack {
                Ellipse()
                    .stroke(ink.opacity(0.15),
                            style: StrokeStyle(lineWidth: compact ? 8 : 13))
                    .padding(.horizontal, w * 0.09)
                    .padding(.vertical, h * 0.15)
                Ellipse()
                    .stroke(muted.opacity(0.58),
                            style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    .padding(.horizontal, w * 0.09)
                    .padding(.vertical, h * 0.15)
                // Draw on the SAME horizontal oval as the gray road.
                // Rotating a non-square SwiftUI Ellipse view deforms its
                // rendered bounds into the tall vertical oval seen in Build 23.
                IMUNRallyTrackArc(progress: fraction)
                    .stroke(accent, style: StrokeStyle(
                        lineWidth: compact ? 5 : 9,
                        lineCap: .round))
                Image(systemName: "car.side.fill")
                    .font(.system(size: compact ? 15 : 26, weight: .black))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.36), radius: 6)
                    .position(x: w/2 + radiusX * CGFloat(cos(angle)),
                              y: h/2 + radiusY * CGFloat(sin(angle)))
                VStack(spacing: compact ? 2 : 7) {
                    Text(count)
                        .font(.system(size: compact ? 17 : 35,
                                      weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                    Text(compact ? "LAPS" : "SET CHECKPOINTS")
                        .font(.system(size: compact ? 7 : 10, weight: .heavy,
                                      design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(muted)
                }
                if !compact {
                    HStack {
                        Image(systemName: "flag.checkered")
                        Text(done == planned && planned > 0 ? "FINISH LINE" : "ON TRACK")
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                    .position(x: w/2, y: h - 4)
                }
            }
        }
    }

    private var heritage: some View {
        VStack(spacing: compact ? 3 : 11) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: compact ? 19 : 34, weight: .light))
                .foregroundStyle(accent)
            Text(count)
                .font(.system(size: compact ? 21 : 43, weight: .medium,
                              design: .serif)).monospacedDigit()
                .foregroundStyle(ink)
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    Rectangle()
                        .fill(fraction >= Double(i+1)/5 ? accent : muted.opacity(0.17))
                        .frame(height: compact ? 4 : 6)
                }
            }
            Text(compact ? "CLUB" : "THE TRAINING LEDGER")
                .font(.system(size: compact ? 8 : 11, weight: .semibold, design: .serif))
                .tracking(1.1)
                .foregroundStyle(muted)
        }
        .padding(compact ? 7 : 18)
        .frame(maxWidth: .infinity)
        .overlay(Rectangle().stroke(accent.opacity(0.5), lineWidth: 1))
        .overlay(Rectangle().stroke(accent.opacity(0.18), lineWidth: 1).padding(5))
    }

    private var retro: some View {
        VStack(spacing: compact ? 5 : 15) {
            Text(compact ? "SCORE" : "SESSION SCOREBOARD")
                .font(.system(size: compact ? 8 : 12, weight: .black,
                              design: .monospaced))
                .tracking(2)
                .foregroundStyle(muted)
            HStack(spacing: 3) {
                digitBlock(String(format: "%02d", done))
                Text(":")
                    .foregroundStyle(accent)
                    .font(.system(size: compact ? 16 : 29, weight: .black))
                digitBlock(String(format: "%02d", planned))
            }
            Text("SETS • DONE / PLANNED")
                .font(.system(size: compact ? 7 : 10, weight: .bold,
                              design: .monospaced))
                .foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func digitBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(size: compact ? 16 : 35, weight: .black,
                          design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(accent)
            .padding(.horizontal, compact ? 4 : 13)
            .padding(.vertical, compact ? 5 : 12)
            .background(ink.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 4))
            .overlay(Rectangle().fill(ink.opacity(0.12))
                .frame(height: 1))
    }

    private var techno: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 17) {
            HStack(alignment: .firstTextBaseline) {
                Text(count)
                    .font(.system(size: compact ? 21 : 43, weight: .medium,
                                  design: .monospaced))
                    .foregroundStyle(ink)
                Spacer(minLength: 0)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: compact ? 13 : 25))
                    .foregroundStyle(accent)
            }
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<16, id: \.self) { i in
                    Capsule()
                        .fill(fraction >= Double(i+1)/16 ? accent : muted.opacity(0.16))
                        .frame(height: CGFloat((i*7)%9+5) * (compact ? 2 : 4))
                        .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            Text(compact ? "TELEMETRY" : "TRAINING TELEMETRY / SETS COMPLETE")
                .font(.system(size: compact ? 7 : 10, weight: .medium,
                              design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(muted)
        }
        .padding(compact ? 5 : 16)
    }

    private var coast: some View {
        GeometryReader { geometry in
            let h = geometry.size.height
            ZStack(alignment: .bottom) {
                IMUNWaveShape(level: fraction)
                    .fill(accent.opacity(0.32))
                IMUNWaveShape(level: max(0, fraction - 0.065))
                    .fill(IMUNStyle.palette.supporting.opacity(0.22))
                VStack(spacing: compact ? 4 : 9) {
                    Image(systemName: "water.waves")
                        .font(.system(size: compact ? 16 : 31))
                        .foregroundStyle(accent)
                    Text(count)
                        .font(.system(size: compact ? 20 : 42,
                                      weight: .light, design: .rounded))
                        .foregroundStyle(ink)
                    Text(compact ? "TIDE" : "TRAINING TIDE")
                        .font(.system(size: compact ? 8 : 11, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: h)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 22))
        }
    }

    private var fieldNotes: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h*0.75))
                    path.addCurve(to: CGPoint(x:w, y:h*0.27),
                                  control1: CGPoint(x:w*0.27, y:h*0.12),
                                  control2: CGPoint(x:w*0.72, y:h*0.96))
                }
                .stroke(muted.opacity(0.32),
                        style: StrokeStyle(lineWidth: 3, dash: [5, 4]))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h*0.75))
                    path.addCurve(to: CGPoint(x:w, y:h*0.27),
                                  control1: CGPoint(x:w*0.27, y:h*0.12),
                                  control2: CGPoint(x:w*0.72, y:h*0.96))
                }
                .trim(from: 0, to: fraction)
                .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                Image(systemName: "figure.hiking")
                    .font(.system(size: compact ? 17 : 29))
                    .foregroundStyle(accent)
                    .position(x: w*0.16, y: h*0.21)
                VStack {
                    Spacer()
                    HStack {
                        Text("TRAIL / \(count)")
                            .font(.system(size: compact ? 9 : 14,
                                          weight: .bold, design: .monospaced))
                            .foregroundStyle(ink)
                        Spacer()
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(accent)
                    }
                }
            }
            .padding(5)
        }
    }

    private var discipline: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 22) {
            Text(count)
                .font(.system(size: compact ? 26 : 55, weight: .black,
                              design: .monospaced))
                .tracking(-1.6)
                .foregroundStyle(ink)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(muted.opacity(0.24))
                    Rectangle().fill(accent)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: compact ? 7 : 15)
            Text(compact ? "EXECUTE" : "WORK COMPLETED. NOTHING EXTRA.")
                .font(.system(size: compact ? 8 : 11, weight: .bold,
                              design: .monospaced))
                .foregroundStyle(muted)
        }
        .padding(compact ? 3 : 18)
    }

    private var atelier: some View {
        HStack(alignment: .center, spacing: compact ? 5 : 22) {
            Rectangle().fill(accent).frame(width: compact ? 2 : 3)
            VStack(alignment: .leading, spacing: compact ? 3 : 10) {
                Text(compact ? "No. 01" : "THE DAILY EDITION")
                    .font(.system(size: compact ? 7 : 12, weight: .medium,
                                  design: .serif))
                    .tracking(1.3)
                    .foregroundStyle(muted)
                Text(String(done))
                    .font(.system(size: compact ? 28 : 67, weight: .light,
                                  design: .serif))
                    .foregroundStyle(ink)
                Text("of \(planned) sets")
                    .font(.system(size: compact ? 9 : 15, weight: .light,
                                  design: .serif))
                    .foregroundStyle(muted)
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? 4 : 18)
    }
}

/// A vector tide line whose height is driven only by measured set completion.
private struct IMUNWaveShape: Shape {
    let level: Double
    func path(in rect: CGRect) -> Path {
        let height = rect.height
        let y = height * (1 - min(1, max(0, level)))
        var path = Path()
        path.move(to: CGPoint(x: 0, y: y))
        path.addCurve(to: CGPoint(x: rect.width, y: y),
                      control1: CGPoint(x: rect.width * 0.30, y: y - 10),
                      control2: CGPoint(x: rect.width * 0.70, y: y + 10))
        path.addLine(to: CGPoint(x: rect.width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}


/// A bounded elliptical arc starting at twelve o'clock. Unlike rotating an
/// Ellipse view, this uses the actual fitted track radii, so 100% completion
/// draws exactly on top of the horizontal gray road in every aspect ratio.
private struct IMUNRallyTrackArc: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        let fraction = max(0, min(1, progress))
        guard fraction > 0, rect.width > 0, rect.height > 0 else {
            return Path()
        }
        let rx = rect.width * 0.41
        let ry = rect.height * 0.35
        let cx = rect.midX
        let cy = rect.midY
        let steps = max(2, Int(ceil(120 * fraction)))
        var path = Path()
        for step in 0...steps {
            let angle = -Double.pi / 2 +
                2 * Double.pi * fraction * Double(step) / Double(steps)
            let point = CGPoint(x: cx + rx * CGFloat(cos(angle)),
                                y: cy + ry * CGFloat(sin(angle)))
            if step == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        return path
    }
}
