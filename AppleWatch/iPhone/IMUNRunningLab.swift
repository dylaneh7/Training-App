import SwiftUI
import Charts

/// Running Lab: measured evidence first, plain-language interpretation second.
/// No pace, gait or running-dynamics value is generated for an absent source.
struct IMUNRunningLabPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge

    private var runs: [HCProgressRun] {
        IMUNRunningIntelligence.uniqueRuns(coach.runHistory)
    }
    private var load: IMUNRunningLoad {
        IMUNRunningIntelligence.weeklyLoad(runs)
    }
    private var efforts: [IMUNRunningBestEffort] {
        IMUNRunningIntelligence.bestEfforts(runs)
    }
    private var totalRecordedMiles: Double {
        runs.compactMap(\.distanceMeters).reduce(0, +) /
            IMUNRunningIntelligence.mile
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 19) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("IMUN / RUNNING LAB")
                        .font(HCDesign.label(10))
                        .tracking(1.8)
                        .foregroundStyle(HCDesign.aqua)
                    Text("Every mile has a story.")
                        .font(HCDesign.display(30))
                        .foregroundStyle(HCDesign.ink)
                    Text("A measured, source-aware record of running performance.")
                        .font(.system(size: 13))
                        .foregroundStyle(HCDesign.secondary)
                }
                IMUNRunLoadCard(load: load)
                HStack(spacing: 10) {
                    HCCard {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(String(format: "%.1f", totalRecordedMiles))
                                .font(HCDesign.metric(26))
                                .foregroundStyle(HCDesign.ink)
                            Text("Recorded miles")
                                .font(HCDesign.label(10))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                    HCCard {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(runs.count)")
                                .font(HCDesign.metric(26))
                                .foregroundStyle(HCDesign.ink)
                            Text("Unique run records")
                                .font(HCDesign.label(10))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                if !efforts.isEmpty {
                    HCSectionTitle(title: "Best recorded efforts",
                                   detail: "Whole-session distance matches")
                    HCCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(efforts) { effort in
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(effort.distanceName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(HCDesign.ink)
                                        Text(effort.date + " · " + effort.source)
                                            .font(.system(size: 10))
                                            .foregroundStyle(HCDesign.secondary)
                                    }
                                    Spacer()
                                    Text(IMUNRunningLabDetail.duration(effort.timeSeconds))
                                        .font(HCDesign.metric(18))
                                        .monospacedDigit()
                                        .foregroundStyle(HCDesign.electric)
                                }
                            }
                            Text("Matches complete runs near each benchmark distance. Not rolling 1K/5K efforts, official race PRs, or inferred split times.")
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                HCSectionTitle(title: "Recorded runs",
                               detail: "Apple Watch · Garmin · connected sources")
                if runs.isEmpty {
                    HCCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Running Lab is ready.")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Connect Apple Health or import Garmin/Tredict workouts to start building an evidence-based running history.")
                                .font(.system(size: 12))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                ForEach(Array(runs.prefix(90))) { run in
                    NavigationLink {
                        IMUNRunningLabDetail(run: run, history: runs)
                    } label: {
                        HStack(spacing: 13) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(run.date.uppercased())
                                    .font(HCDesign.label(10))
                                    .tracking(1.1)
                                    .foregroundStyle(HCDesign.aqua)
                                Text(run.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(HCDesign.ink)
                                Text(run.source)
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            Spacer(minLength: 5)
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(run.distanceMeters.map {
                                    String(format:"%.2f mi", $0 / IMUNRunningIntelligence.mile)
                                } ?? "—")
                                .font(HCDesign.metric(17))
                                .foregroundStyle(HCDesign.ink)
                                Text(IMUNRunningIntelligence.formatPace(
                                    IMUNRunningIntelligence.pacePerMile(run)) + "/mi")
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(HCDesign.secondary)
                        }
                        .padding(15)
                        .background(HCDesign.card,
                                    in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                Text("Source labels are preserved. A GPS recording duplicated across services is counted once when its distance, time and date match. Imported totals can be incomplete.")
                    .font(.system(size: 10))
                    .foregroundStyle(HCDesign.secondary)
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationTitle("Running Lab")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct IMUNRunLoadCard: View {
    let load: IMUNRunningLoad
    var body: some View {
        HCCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("TRAINING VOLUME")
                            .font(HCDesign.label(10))
                            .tracking(1.5)
                            .foregroundStyle(HCDesign.aqua)
                        Text("Your last seven days")
                            .font(HCDesign.display(20))
                            .foregroundStyle(HCDesign.ink)
                    }
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(HCDesign.aqua)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.1f", load.recent7Miles))
                        .font(HCDesign.metric(37))
                        .foregroundStyle(HCDesign.ink)
                    Text("miles")
                        .font(.system(size: 13))
                        .foregroundStyle(HCDesign.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(load.distinctRuns7) runs")
                            .font(HCDesign.metric(16))
                        Text(String(format: "%.1f mi / 28 days", load.recent28Miles))
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                if let reference = load.prior21WeeklyMiles,
                   load.comparisons >= 3 {
                    let difference = load.recent7Miles - reference
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                        Text(String(format:
                            "%.1f mi %@ than your previous three-week average (%.1f mi/week)",
                            abs(difference), difference >= 0 ? "more" : "less", reference))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
                } else {
                    Text("A comparable training-volume baseline needs more recorded weeks.")
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                }
                if let share = load.longRunShare, load.distinctRuns7 >= 2 {
                    Text(String(format:
                        "Largest run supplied %.0f%% of this week's measured mileage.",
                        share * 100))
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                }
            }
        }
    }
}

struct IMUNRunningLabDetail: View {
    let run: HCProgressRun
    let history: [HCProgressRun]
    @AppStorage("hcRunMaximumHeartRate") private var maximumHeartRate = 0
    @State private var showMaxEditor = false
    @State private var maxDraft = ""
    @State private var maxError = false

    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total/3600,
                          (total%3600)/60, total%60)
        }
        return String(format: "%d:%02d", total/60, total%60)
    }
    private var insights: [IMUNRunningObservation] {
        IMUNRunningIntelligence.sessionInsights(run, history: history)
    }
    private var zones: [IMUNRunningZone] {
        IMUNRunningIntelligence.heartRateZones(
            run, maxBPM: maximumHeartRate)
    }
    private var metricKinds: [(key:String, name:String,unit:String)] {
        [
            ("runningSpeed", "Recorded running speed", "m/s"),
            ("runningPower", "Running power", "W"),
            ("runningStrideLength", "Stride length", "m"),
            ("runningGroundContactTime", "Ground contact time", "ms"),
            ("runningVerticalOscillation", "Vertical oscillation", "cm")
        ]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("IMUN / SESSION INTELLIGENCE")
                        .font(HCDesign.label(10))
                        .tracking(1.6)
                        .foregroundStyle(HCDesign.aqua)
                    Text(run.title)
                        .font(HCDesign.display(29))
                        .foregroundStyle(HCDesign.ink)
                    Text(run.date + " · " + run.source)
                        .font(.system(size: 12))
                        .foregroundStyle(HCDesign.secondary)
                }
                IMUNRunSessionNumbers(run: run)
                HCCard {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("RUN ASSESSMENT")
                            .font(HCDesign.label(10))
                            .tracking(1.2)
                            .foregroundStyle(HCDesign.aqua)
                        ForEach(insights) { insight in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(insight.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HCDesign.ink)
                                Text(insight.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(HCDesign.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }
                        NavigationLink {
                            PremiumCoachConversation(
                                launchContext: IMUNRunningIntelligence.coachContext(
                                    for: run, history: history,
                                    maximumBPM: maximumHeartRate))
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text("Explore this run with IsAIah")
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HCDesign.electric)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Text("IsAIah receives this run's summary only when you choose to send a question. Comparisons are advisory, not a form or injury diagnosis.")
                            .font(.system(size: 10))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                IMUNRunZoneCard(zones: zones,
                                maximumHeartRate: maximumHeartRate,
                                showEditor: $showMaxEditor)
                ForEach(metricKinds, id: \.key) { item in
                    let samples = IMUNRunningIntelligence.metric(run, kind: item.key)
                    if !samples.isEmpty {
                        IMUNRunningSeriesCard(title: item.name,
                                              unit: item.unit,
                                              samples: samples)
                    }
                }
                if !run.heartRateTrace.isEmpty {
                    HCCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HCSectionTitle(title: "Heart rate",
                                           detail: "Recorded · " + run.source)
                            Chart(run.heartRateTrace) { point in
                                LineMark(x: .value("Time", point.at),
                                         y: .value("bpm", point.bpm))
                                .foregroundStyle(HCDesign.aqua)
                            }
                            .frame(height: 160)
                            .chartYAxisLabel("bpm")
                        }
                    }
                }
                if let gps = run.routeMileSplits, !gps.isEmpty {
                    HCSectionTitle(title: "Route-derived splits",
                                   detail: "GPS estimate · not recorded lap events")
                    HCCard {
                        VStack(spacing: 12) {
                            ForEach(gps) { split in
                                HStack {
                                    Text("Mile \(split.index)")
                                        .font(.system(size: 13, weight: .semibold))
                                    Spacer()
                                    Text(Self.duration(split.elapsedSeconds))
                                        .font(HCDesign.metric(16))
                                        .monospacedDigit()
                                }
                            }
                            Text("Computed from timestamped GPS points when route coverage and plausible speed checks pass. Watch lap events remain separate.")
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                HCSectionTitle(title: "Source & limitations")
                HCCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recorded by " + run.source)
                            .font(.system(size: 13, weight: .semibold))
                        if let bundle = run.sourceBundleID {
                            Text(bundle)
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                        }
                        Text("Apple Watch running dynamics appear when shared to HealthKit. Garmin and Tredict records retain only fields the connected provider actually exposes. Motion-derived watch gait, measured foot strike, biomechanical injury risk, and all-day training readiness are not inferred here.")
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationTitle("Running Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMaxEditor) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Maximum HR (bpm)", text: $maxDraft)
                            .keyboardType(.numberPad)
                        if maxError {
                            Text("Enter a known or professionally assessed maximum between 120 and 240 bpm.")
                                .foregroundStyle(HCDesign.danger)
                        }
                    } header: { Text("Personal heart-rate zones") }
                    footer: {
                        Text("Enter your own measured or assessed maximum HR. iMun does not estimate this from age and does not label these zones as laboratory lactate thresholds.")
                    }
                }
                .navigationTitle("HR Zone Setup")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showMaxEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let result = Int(maxDraft),
                                  (120...240).contains(result) else {
                                maxError = true
                                return
                            }
                            maximumHeartRate = result
                            maxError = false
                            showMaxEditor = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onChange(of: showMaxEditor) { _, visible in
            if visible {
                maxDraft = maximumHeartRate > 0 ?
                    String(maximumHeartRate) : ""
                maxError = false
            }
        }
    }
}

private struct IMUNRunSessionNumbers: View {
    let run: HCProgressRun
    private func format(_ number: Double?, unit: String, digits: Int = 0) -> String {
        number.map {
            $0.formatted(.number.precision(.fractionLength(digits))) + unit
        } ?? "—"
    }
    var body: some View {
        HCCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 11) {
                    HCMetricBlock(label: "Distance",
                        value: format(run.distanceMeters.map {
                            $0 / IMUNRunningIntelligence.mile
                        }, unit: " mi", digits: 2))
                    HCMetricBlock(label: "Time",
                        value: run.durationSeconds.map(
                            IMUNRunningLabDetail.duration) ?? "—")
                }
                HStack(spacing: 11) {
                    HCMetricBlock(label: "Average pace",
                        value: IMUNRunningIntelligence.formatPace(
                            IMUNRunningIntelligence.pacePerMile(run)) + "/mi")
                    HCMetricBlock(label: "Average HR",
                                  value: format(run.averageBPM, unit: " bpm"))
                }
                HStack(spacing: 11) {
                    HCMetricBlock(label: "Power",
                                  value: format(run.averagePowerWatts, unit: " W"))
                    HCMetricBlock(label: "Cadence",
                                  value: format(run.averageCadenceSPM, unit: " spm"))
                }
                HStack(spacing: 11) {
                    HCMetricBlock(label: "Stride",
                        value: format(run.averageStrideLengthMeters,
                                      unit: " m", digits: 2))
                    HCMetricBlock(label: "Contact",
                        value: format(run.averageGroundContactTimeMS,
                                      unit: " ms"))
                }
                HStack(spacing: 11) {
                    HCMetricBlock(label: "Oscillation",
                        value: format(run.averageVerticalOscillationCM,
                                      unit: " cm", digits: 1))
                    HCMetricBlock(label: "Elevation",
                        value: format(run.elevationGainMeters, unit: " m"))
                }
            }
        }
    }
}

private struct IMUNRunZoneCard: View {
    let zones: [IMUNRunningZone]
    let maximumHeartRate: Int
    @Binding var showEditor: Bool

    private var total: Double {
        zones.reduce(0.0) { $0 + $1.seconds }
    }
    var body: some View {
        HCCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HEART-RATE DISTRIBUTION")
                            .font(HCDesign.label(10))
                            .foregroundStyle(HCDesign.aqua)
                        Text(maximumHeartRate > 0 ?
                            "Based on your selected HR maximum" :
                            "Choose a measured maximum HR")
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    Spacer()
                    Button(maximumHeartRate > 0 ? "Edit" : "Set") {
                        showEditor = true
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .tint(HCDesign.electric)
                }
                if zones.isEmpty || total < 60 {
                    Text("Zone time requires a valid maximum HR and sufficient time-stamped heart-rate measurements. No age-based maximum is assumed.")
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                } else {
                    ForEach(zones) { zone in
                        HStack(spacing: 10) {
                            Text(zone.title)
                                .font(HCDesign.label(11))
                                .frame(width: 26, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(HCDesign.raised)
                                    Capsule().fill(HCDesign.electric)
                                        .frame(width: max(2, geo.size.width *
                                            CGFloat(zone.seconds / total)))
                                }
                            }
                            .frame(height: 6)
                            Text(IMUNRunningLabDetail.duration(zone.seconds))
                                .font(HCDesign.label(11))
                                .monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                        }
                        .foregroundStyle(HCDesign.ink)
                    }
                    Text("Time between successive HR observations is counted only when gaps are 75 seconds or less. Zones are percentage-of-max estimates, not measured metabolic thresholds.")
                        .font(.system(size: 10))
                        .foregroundStyle(HCDesign.secondary)
                }
            }
        }
    }
}

private struct IMUNRunningSeriesCard: View {
    let title: String
    let unit: String
    let samples: [HCRunSensorReading]

    var body: some View {
        HCCard {
            VStack(alignment: .leading, spacing: 10) {
                HCSectionTitle(title: title, detail: "Recorded · " + unit)
                Chart(samples) { row in
                    LineMark(x: .value("Time", row.at),
                             y: .value(title, row.value))
                        .foregroundStyle(HCDesign.aqua)
                }
                .frame(height: 145)
                Text("\(samples.count) published samples in this chart. Values and sample spacing come from the recording provider.")
                    .font(.system(size: 10))
                    .foregroundStyle(HCDesign.secondary)
            }
        }
    }
}
