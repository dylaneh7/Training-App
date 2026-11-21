import SwiftUI
import Charts

/// Deliberate Running Lab layout: a small number of clear sections rather
/// than a never-ending page of unrelated metric tiles.
struct IMUNRunningAdvancedOverview: View {
    let runs: [HCProgressRun]
    let planned: [HCPlannedSession]
    @ObservedObject private var logbook = IMUNRunningLogbook.shared

    private var projections: [IMUNRaceProjection] {
        IMUNRunAdvancedAnalytics.raceForecasts(runs)
    }
    private var goalSummary: [String] {
        logbook.goalStatus(in: runs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HCSectionTitle(title: "Your running program",
                           detail: "Personal goals · shoes · race calendar")
            NavigationLink {
                IMUNRunningTrainingTools(runs: runs, planned: planned)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(HCDesign.electric)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Training & equipment")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HCDesign.ink)
                        Text(goalSummary.isEmpty ?
                            "Set your mileage target, shoes and races" :
                            goalSummary.joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 5)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                }
                .padding(15)
                .background(HCDesign.card,
                            in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if !projections.isEmpty {
                HCSectionTitle(title: "Indicative race models",
                               detail: "Not a guaranteed finish time")
                HCCard {
                    VStack(alignment: .leading, spacing: 13) {
                        ForEach(projections) { prediction in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(prediction.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(HCDesign.ink)
                                    Spacer()
                                    Text(IMUNRunningLabDetail.duration(
                                        prediction.predictedSeconds))
                                        .font(HCDesign.metric(17))
                                        .foregroundStyle(HCDesign.electric)
                                }
                                Text("Illustrative range " +
                                     IMUNRunningLabDetail.duration(prediction.lowerSeconds) +
                                     " – " +
                                     IMUNRunningLabDetail.duration(prediction.upperSeconds))
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                                Text("From recorded " + prediction.basedOn)
                                    .font(.system(size: 10))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                        Text("A simple distance–time model (exponent 1.06) using recorded whole-run efforts. Racing intent, course, weather, endurance preparation and device accuracy may change results substantially.")
                            .font(.system(size: 10))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
            }
            if let adherence = logbook.scheduleAdherence(planned, runs: runs) {
                HCCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checklist")
                            .foregroundStyle(HCDesign.aqua)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Training adherence")
                                .font(.system(size: 13, weight: .semibold))
                            Text("\(adherence.matched) of \(adherence.planned) scheduled running dates have a recorded run or completed calendar entry in the past 28 days.")
                                .font(.system(size: 11))
                                .foregroundStyle(HCDesign.secondary)
                            Text("Matched calendar days do not verify prescribed intervals, target heart rate, or intensity.")
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct IMUNRunningAdvancedSession: View {
    let run: HCProgressRun
    let history: [HCProgressRun]
    @AppStorage("hcRunCriticalPowerWatts") private var criticalPower = 0
    @AppStorage("hcRunThresholdPaceSecondsPerMile") private var thresholdPace = 0
    @State private var editThresholds = false
    @State private var powerDraft = ""
    @State private var paceDraft = ""
    @State private var showJournal = false
    @ObservedObject private var logbook = IMUNRunningLogbook.shared

    private var efforts: [IMUNRunBestSegment] {
        IMUNRunAdvancedAnalytics.bestRouteSegments(run)
    }
    private var surges: [IMUNRunSurge] {
        IMUNRunAdvancedAnalytics.candidateSurges(run)
    }
    private var terrain: IMUNRunRouteAssessment? {
        IMUNRunAdvancedAnalytics.routeAssessment(run)
    }
    private var mechanics: [IMUNRunningObservation] {
        IMUNRunAdvancedAnalytics.mechanicsComparison(run, history: history)
    }
    private var heartRecovery: [IMUNRunningObservation] {
        IMUNRunAdvancedAnalytics.heartRateRecovery(run)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("RUNNING LAB / DEEP ANALYSIS")
                        .font(HCDesign.label(10))
                        .tracking(1.7)
                        .foregroundStyle(HCDesign.aqua)
                    Text("The evidence within your run.")
                        .font(HCDesign.display(27))
                        .foregroundStyle(HCDesign.ink)
                    Text(run.date + " · " + run.source)
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                }
                HCCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Personal training thresholds")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer(minLength: 4)
                            Button("Edit") { editThresholds = true }
                                .font(.system(size: 12, weight: .medium))
                                .tint(HCDesign.electric)
                        }
                        Text("Critical power: " + (criticalPower > 0 ?
                             "\(criticalPower) W" : "not set"))
                        Text("Threshold pace: " + (thresholdPace > 0 ?
                             IMUNRunningIntelligence.formatPace(
                                Double(thresholdPace)) + "/mi" : "not set"))
                        Text("You enter established thresholds. iMun never invents them from a single run, and these are training zones rather than clinical measurements.")
                            .font(.system(size: 10))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    .font(.system(size: 12))
                }
                if let zone = IMUNRunAdvancedAnalytics.powerZones(
                    run, criticalPower: criticalPower) {
                    IMUNRunningDistributionCard(title: "Power distribution", data: zone)
                }
                if let zone = IMUNRunAdvancedAnalytics.paceZones(
                    run, thresholdSecondsPerMile: thresholdPace) {
                    IMUNRunningDistributionCard(title: "Pace distribution", data: zone)
                }
                if !efforts.isEmpty {
                    HCSectionTitle(title: "Rolling GPS best efforts",
                                   detail: "Within this run")
                    HCCard {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(efforts) { result in
                                HStack {
                                    Text(result.distanceLabel)
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Text(IMUNRunningLabDetail.duration(
                                        result.elapsedSeconds))
                                        .font(HCDesign.metric(17))
                                }
                            }
                            Text("Route-derived, interpolated over consecutive timestamped GPS samples. It can be inaccurate when GPS reception, pauses or downsampling limit precision; not an official PR.")
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                } else {
                    IMUNRunningUnavailableCard(
                        title: "Rolling GPS efforts",
                        reason: "Requires sufficiently complete timestamped GPS coverage from the recording source.")
                }
                if !surges.isEmpty {
                    HCSectionTitle(title: "Faster segments",
                                   detail: "Candidate efforts · not prescribed intervals")
                    HCCard {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(surges) { segment in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(segment.start.formatted(
                                            date: .omitted,
                                            time: .shortened))
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(String(format: "Mean speed %.1f m/s",
                                                    segment.meanSpeedMPS))
                                            .font(.system(size: 10))
                                            .foregroundStyle(HCDesign.secondary)
                                    }
                                    Spacer()
                                    Text(IMUNRunningLabDetail.duration(
                                        segment.durationSeconds))
                                        .font(HCDesign.metric(17))
                                }
                            }
                            Text("Detected from source-published speed elevated above the session median. A steady progression, GPS noise or hills may also trigger a segment.")
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                if let terrain {
                    HCSectionTitle(title: "Terrain & route quality",
                                   detail: "Recorded GPS and elevation")
                    HCCard {
                        VStack(alignment: .leading, spacing: 11) {
                            HStack {
                                IMUNRunningSmallValue(label: "Route coverage",
                                    value: terrain.coveredFraction.map {
                                        String(format: "%.0f%%", $0 * 100)
                                    } ?? "—")
                                IMUNRunningSmallValue(label: "Ascent",
                                    value: terrain.elevationGainMeters.map {
                                        String(format: "%.0f m", $0)
                                    } ?? "—")
                            }
                            HStack {
                                IMUNRunningSmallValue(label: "Descent",
                                    value: terrain.elevationLossMeters.map {
                                        String(format: "%.0f m", $0)
                                    } ?? "—")
                                IMUNRunningSmallValue(label: "Uphill track",
                                    value: String(format: "%.2f km",
                                        terrain.uphillDistanceMeters / 1000))
                            }
                            Text("\(terrain.reliableSegments) accepted GPS segments; \(terrain.discardedSegments) rejected gaps or implausible changes.")
                                .font(.system(size: 11))
                                .foregroundStyle(HCDesign.secondary)
                            Text("Elevation noise, surface, and grade may explain pace differences. This is an observed course profile, not a calibrated grade-adjusted pace or energy-cost model.")
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                let pacing = IMUNRunAdvancedAnalytics.pacingPattern(run)
                let economy = IMUNRunAdvancedAnalytics.aerobicEfficiency(
                    run, history: history)
                let climate = logbook.conditionsComparison(run, history: history)
                if pacing != nil || economy != nil || climate != nil {
                    HCSectionTitle(title: "Pacing & conditions",
                                   detail: "Comparable evidence · not causation")
                    HCCard {
                        VStack(alignment: .leading, spacing: 11) {
                            if let pacing {
                                Text(pacing.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(pacing.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            if let economy {
                                Text(economy.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(economy.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            if let climate {
                                Text("Manually recorded conditions")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(climate)
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                    }
                }
                if !mechanics.isEmpty || !heartRecovery.isEmpty {
                    HCSectionTitle(title: "Athlete-specific comparisons",
                                   detail: "Observed, not diagnostic")
                    HCCard {
                        VStack(alignment: .leading, spacing: 13) {
                            ForEach(heartRecovery + mechanics) { item in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(HCDesign.ink)
                                    Text(item.detail)
                                        .font(.system(size: 11))
                                        .foregroundStyle(HCDesign.secondary)
                                        .fixedSize(horizontal: false,
                                                   vertical: true)
                                }
                            }
                        }
                    }
                }
                HCSectionTitle(title: "Run notes, conditions & fueling",
                               detail: "Your observations, not sensors")
                NavigationLink {
                    IMUNRunningJournalEditor(run: run)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .foregroundStyle(HCDesign.electric)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Add your run journal")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(HCDesign.ink)
                            Text(logbook.note(for: run.id).notes.isEmpty ?
                                "Effort · shoes · fuel · hydration · temperature" :
                                "Your session notes are saved on this iPhone")
                                .font(.system(size: 11))
                                .foregroundStyle(HCDesign.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(HCDesign.secondary)
                    }
                    .padding(15)
                    .background(HCDesign.card,
                                in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                Text("All charts and comparisons here depend on source data. No medical diagnosis, automated treatment, verified footwear biomechanics, or climate-adjusted pace is claimed.")
                    .font(.system(size: 10))
                    .foregroundStyle(HCDesign.secondary)
            }
            .padding(17)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationTitle("Deep Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editThresholds) {
            NavigationStack {
                Form {
                    Section("Your measured training thresholds") {
                        TextField("Critical power, watts",
                                  text: $powerDraft)
                            .keyboardType(.numberPad)
                        TextField("Threshold pace, seconds per mile",
                                  text: $paceDraft)
                            .keyboardType(.numberPad)
                        Text("Leave blank to disable a zone model. Enter an established threshold only; the app does not guess.")
                            .font(.footnote)
                    }
                }
                .navigationTitle("Run Zones")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editThresholds = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let p = Int(powerDraft) ?? 0
                            let t = Int(paceDraft) ?? 0
                            guard (p == 0 || (100...900).contains(p)),
                                  (t == 0 || (230...1200).contains(t))
                            else { return }
                            criticalPower = p
                            thresholdPace = t
                            editThresholds = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onChange(of: editThresholds) { _, visible in
            if visible {
                powerDraft = criticalPower == 0 ? "" : String(criticalPower)
                paceDraft = thresholdPace == 0 ? "" : String(thresholdPace)
            }
        }
    }
}

private struct IMUNRunningSmallValue: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(HCDesign.metric(18))
                .foregroundStyle(HCDesign.ink)
            Text(label)
                .font(HCDesign.label(10))
                .foregroundStyle(HCDesign.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IMUNRunningUnavailableCard: View {
    let title: String
    let reason: String
    var body: some View {
        HCCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(reason)
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
            }
        }
    }
}

private struct IMUNRunningDistributionCard: View {
    let title: String
    let data: IMUNRunZones
    var body: some View {
        HCCard {
            VStack(alignment: .leading, spacing: 11) {
                HCSectionTitle(title: title, detail: data.thresholdLabel)
                ForEach(data.labels.indices, id: \.self) { index in
                    HStack(spacing: 9) {
                        Text(data.labels[index])
                            .font(HCDesign.label(10))
                            .frame(width: 72, alignment: .leading)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(HCDesign.raised)
                                Capsule().fill(HCDesign.electric)
                                    .frame(width: max(1,
                                        geometry.size.width *
                                        CGFloat(data.seconds[index] /
                                            max(1, data.recordedSeconds))))
                            }
                        }
                        .frame(height: 6)
                        Text(IMUNRunningLabDetail.duration(data.seconds[index]))
                            .font(HCDesign.label(10))
                            .monospacedDigit()
                            .frame(width: 45, alignment: .trailing)
                    }
                    .foregroundStyle(HCDesign.ink)
                }
                Text("Zone time includes only adjacent recorded samples up to 90 seconds apart. Missing time is not assigned to a zone.")
                    .font(.system(size: 10))
                    .foregroundStyle(HCDesign.secondary)
            }
        }
    }
}
