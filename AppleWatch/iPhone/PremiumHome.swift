import SwiftUI
import Charts
import MapKit
import PhotosUI
import UniformTypeIdentifiers
import PDFKit
import UIKit

/// A selected document or photo belongs to the pending chat composer, not
/// to workout history. No bytes are transmitted until the athlete taps Send.
struct IMUNCoachAttachment: Identifiable {
    let id = UUID()
    let name: String
    let kind: String           // "image" or "text"
    let content: String        // compressed JPEG base64 or extracted text
    let bytes: Int

    var requestPayload: [String: Any] {
        ["name": String(name.prefix(120)), "kind": kind,
         "content": content]
    }
    var label: String {
        kind == "image" ? "Photo · " + name : "File · " + name
    }
}

enum IMUNCoachAttachmentReader {
    enum Failure: LocalizedError {
        case tooLarge, unsupported, emptyText, invalidImage, tooMany
        var errorDescription: String? {
            switch self {
            case .tooLarge: return "This file is too large for a chat attachment. Export a smaller date range or CSV."
            case .unsupported: return "This file format cannot be read yet. Use CSV, JSON, GPX, TCX, XML, TXT, PDF or a photo. Garmin FIT requires a separate decoder."
            case .emptyText: return "No readable text was found in the document. For a scanned PDF, attach a photo or screenshot instead."
            case .invalidImage: return "The selected photo could not be opened."
            case .tooMany: return "Use up to four attachments per message, including at most two photos."
            }
        }
    }

    static func image(data: Data, filename: String) throws -> IMUNCoachAttachment {
        guard let source = UIImage(data: data) else { throw Failure.invalidImage }
        let largest = max(source.size.width, source.size.height)
        guard largest > 0 else { throw Failure.invalidImage }
        let scale = min(CGFloat(1), CGFloat(1200) / largest)
        let target = CGSize(width: max(1, (source.size.width * scale).rounded()),
                            height: max(1, (source.size.height * scale).rounded()))
        let renderer = UIGraphicsImageRenderer(size: target)
        let jpeg = renderer.jpegData(withCompressionQuality: 0.65) { context in
            source.draw(in: CGRect(origin: .zero, size: target))
        }
        guard jpeg.count <= 1_500_000 else { throw Failure.tooLarge }
        return IMUNCoachAttachment(name: filename, kind: "image",
                                   content: jpeg.base64EncodedString(),
                                   bytes: jpeg.count)
    }

    static func document(at url: URL) throws -> IMUNCoachAttachment {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        let resourceSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard resourceSize <= 8_000_000 else { throw Failure.tooLarge }
        let ext = url.pathExtension.lowercased()
        let supportedText: Set<String> = [
            "csv", "tsv", "txt", "json", "gpx", "tcx", "xml", "md", "log"
        ]
        guard ext == "pdf" || supportedText.contains(ext) ||
              ["jpg", "jpeg", "png", "heic", "webp"].contains(ext)
        else { throw Failure.unsupported }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count <= 8_000_000 else { throw Failure.tooLarge }
        if ["jpg", "jpeg", "png", "heic", "webp"].contains(ext) {
            return try image(data: data, filename: url.lastPathComponent)
        }
        let extracted: String?
        if ext == "pdf" {
            extracted = PDFDocument(data: data)?.string
        } else {
            extracted = String(data: data, encoding: .utf8) ??
                        String(data: data, encoding: .utf16)
        }
        guard let excerpt = extracted?.trimmingCharacters(in: .whitespacesAndNewlines),
              !excerpt.isEmpty else { throw Failure.emptyText }
        // These are readable excerpts, not a complete import of giant files.
        let bounded = String(excerpt.prefix(18_000))
        return IMUNCoachAttachment(name: url.lastPathComponent,
                                   kind: "text", content: bounded,
                                   bytes: data.count)
    }
}

// The bottom bar is organized by purpose; individual sports live inside Training.
// Adding cycling, mobility or swimming later does not require another bottom tab.
private enum IMUNTrainingActivity: String, CaseIterable, Identifiable {
    case run
    case weightlifting

    var id: String { rawValue }
    var title: String {
        switch self {
        case .run: return "Run"
        case .weightlifting: return "Weightlifting"
        }
    }
    var symbol: String {
        switch self {
        case .run: return "figure.run"
        case .weightlifting: return "dumbbell.fill"
        }
    }
}

// MARK: - Today: one factual, source-attributed command center
private struct IMUNTodayPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @ObservedObject var appleHealth: HCAppleHealthReader
    let openCoach: () -> Void
    @AppStorage("hcSelectedTab") private var selectedTab = "today"
    @AppStorage("hcTrainingActivity") private var activity = "weightlifting"
    @AppStorage("hcEitanPrimaryWearable") private var preferredSource = "Auto"

    private var today: String { HCPlanBuilder.dateString(Date()) }
    private var lift: HCWorkout? {
        guard let w = coach.workout, w.date == today, !w.exercises.isEmpty else { return nil }
        return w
    }
    private var run: HCRunPlan? {
        guard let r = coach.runPlan, r.date == today, !r.isCompleted else { return nil }
        return r
    }
    private func metric(_ words: [String]) -> HCHealthMetric? {
        let candidates = appleHealth.metrics.filter { m in
            words.contains { m.name.localizedCaseInsensitiveContains($0) } &&
                (preferredSource == "Auto" ||
                 m.source.localizedCaseInsensitiveContains(preferredSource))
        }
        return candidates.sorted { $0.date > $1.date }.first
    }
    private var sleep: HCHealthMetric? { metric(["Total asleep"]) }
    private var hrv: HCHealthMetric? { metric(["HRV", "Heart rate variability"]) }
    private var resting: HCHealthMetric? { metric(["Resting heart"]) }

    private var sessionSummary: String {
        if let lift, let run { return "Strength: \(lift.title) · Run: \(run.title)" }
        if let lift { return "Strength: " + lift.title }
        if let run { return "Run: " + run.title }
        return coach.loading ? "Updating today's calendar…" : "No session scheduled today."
    }
    private var healthSummary: String {
        let available = [
            sleep.map { "sleep \($0.value) (\($0.source))" },
            hrv.map { "HRV \($0.value) (\($0.source))" },
            resting.map { "resting HR \($0.value) (\($0.source))" }
        ].compactMap { $0 }
        return available.isEmpty ? "No recent authorized Health readings loaded." :
            available.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IMUN / TODAY")
                            .font(HCDesign.label(10)).tracking(1.2)
                            .foregroundStyle(HCDesign.electric)
                        Text("Make today count.")
                            .font(HCDesign.display(29))
                            .foregroundStyle(HCDesign.ink)
                    }
                    Spacer(minLength: 8)
                    Text(Date().formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HCDesign.secondary)
                }
                HCCard(accent: HCDesign.electric) {
                    VStack(alignment: .leading, spacing: 12) {
                        HCAccentTag(title: "TODAY'S TRAINING")
                        Text(sessionSummary)
                            .font(HCDesign.display(21))
                            .foregroundStyle(HCDesign.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if let lift {
                            HCMetricBlock(label: "Working sets",
                                          value: "\(coach.completedSets(for: lift).count)/\(lift.prescribedSetCount)")
                        }
                        HStack(spacing: 10) {
                            if lift != nil {
                                Button {
                                    activity = "weightlifting"
                                    if coach.phoneSessionStartedAt == nil {
                                        coach.startPhoneWorkout()
                                    }
                                    selectedTab = "training"
                                } label: {
                                    Label(coach.isWorkoutActive ?
                                          "Resume workout" : "Start workout",
                                          systemImage: "play.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(HCDesign.electric)
                            }
                            if run != nil {
                                Button {
                                    activity = "run"
                                    selectedTab = "training"
                                } label: {
                                    Label("Open run", systemImage: "figure.run")
                                }
                                .buttonStyle(.bordered)
                                .tint(HCDesign.electric)
                            }
                            if lift == nil && run == nil {
                                Button("Open Training") { selectedTab = "training" }
                                    .buttonStyle(.bordered)
                                    .tint(HCDesign.electric)
                            }
                        }
                    }
                }
                IMUNEitanTodayCard(openCoach: openCoach)
                HCSectionTitle(title: "Your recovery", detail: "Latest source readings")
                if appleHealth.loading && appleHealth.metrics.isEmpty {
                    IMUNLoadingPlaceholder(lines: 3, height: 118)
                } else {
                    HStack(alignment: .top, spacing: 9) {
                        IMUNTodaysHealthStat(label: "Sleep", metric: sleep)
                        IMUNTodaysHealthStat(label: "HRV", metric: hrv)
                        IMUNTodaysHealthStat(label: "Resting HR", metric: resting)
                    }
                }
                Button {
                    selectedTab = "health"
                } label: {
                    Label("View Health details", systemImage: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(HCDesign.electric)
                HCCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            IMUNIsaiahMark(size: 32)
                            Text("IsAIah / DAILY BRIEF")
                                .font(HCDesign.label(11))
                        }
                        Text(sessionSummary)
                            .font(.system(size: 13, weight: .semibold))
                        Text(healthSummary)
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                Spacer(minLength: 95)
            }
            .padding(.horizontal, 18)
            .padding(.top, 17)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appleHealth.refreshIfAuthorized() }
    }
}

/// Proactive on-device IsAIah guidance; prompts appear only in the app,
/// never as a surprise remote Health-data share or automatic plan mutation.
private struct IMUNEitanTodayCard: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @AppStorage("hcEitanEnabled") private var showEitan = true
    @AppStorage("hcEitanUseHealth") private var healthEnabled = true
    @AppStorage("hcEitanCoachingEnabled") private var coachingEnabled = true
    @AppStorage("hcEitanNudgeDismissedDay") private var dismissedDay = ""
    let openCoach: () -> Void

    var body: some View {
        if showEitan {
            HCCard(accent: HCDesign.electric) {
                VStack(alignment: .leading, spacing: 11) {
                    heading
                    wellnessContent
                    coachingContent
                }
            }
        }
    }

    private var heading: some View {
HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EITAN / " + (healthEnabled ? "BODY WELLNESS" : "TRAINING"))
                                .font(HCDesign.label(10))
                                .tracking(1)
                                .foregroundStyle(HCDesign.electric)
                            Text("Enduring · Steadfast")
                                .font(.system(size: 12))
                                .foregroundStyle(HCDesign.secondary)
                        }
                        Spacer()
                        Text(healthEnabled
                             ? (coach.eitanSnapshot?.value.map(String.init) ?? "—") + " / 100"
                             : "TRAINING-ONLY")
                            .font(HCDesign.display(24))
                            .monospacedDigit()
                            .foregroundStyle(HCDesign.ink)
                            .minimumScaleFactor(0.65)
                            .lineLimit(1)
                    }
    }

    @ViewBuilder private var wellnessContent: some View {
if healthEnabled {
                        if let snapshot = coach.eitanSnapshot,
                           snapshot.date == HCPlanBuilder.dateString(Date()) {
                            Text("Primary wearable: " + (snapshot.primaryWearable ?? "Auto"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(HCDesign.electric)
                            Text(snapshot.coverage)
                                .font(.system(size: 11))
                                .foregroundStyle(HCDesign.secondary)
                            if coachingEnabled {
                                if snapshot.needsRecoveryConversation &&
                                   dismissedDay != snapshot.date {
                                    HStack(spacing: 8) {
                                        Image(systemName: "moon.zzz.fill")
                                            .foregroundStyle(HCDesign.electric)
                                        Text("IsAIah · Recovery check-in")
                                            .font(.system(size: 13, weight: .semibold))
                                        Spacer()
                                        Button("Dismiss") { dismissedDay = snapshot.date }
                                            .font(.system(size: 11))
                                    }
                                }
                                if dismissedDay != snapshot.date || !snapshot.needsRecoveryConversation {
                                    Text(snapshot.coaching)
                                        .font(.system(size: 12))
                                        .foregroundStyle(HCDesign.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if snapshot.value != nil ||
                                       snapshot.coachingPlan?.needsConversation == true {
                                        Button {
                                            openCoach()
                                        } label: {
                                            Label("Discuss today's training with IsAIah",
                                                  systemImage: "bubble.left.and.text.bubble.right")
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(HCDesign.electric)
                                    }
                                }
                            } else {
                                Text(snapshot.status)
                                    .font(.system(size: 12))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        } else {
                            Text("EITAN needs comparable, authorized Health measurements to establish a personal baseline.")
                                .font(.system(size: 12))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    } else {
                        Text("Health measurements are excluded from EITAN. Training momentum remains available on Apple Watch.")
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                    }
    }

    @ViewBuilder private var coachingContent: some View {
if coachingEnabled {
                        if let strategy = coach.eitanSnapshot?.coachingPlan, healthEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: strategy.mode == "challenge"
                                      ? "bolt.fill" : strategy.mode == "adapt"
                                      ? "slider.horizontal.3" : "moon.stars.fill")
                                Text("IsAIah · " + strategy.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(strategy.confidence + " evidence")
                                    .font(.system(size: 10))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            .foregroundStyle(HCDesign.electric)
                            Text("\(strategy.recordedTrainingStreak) consecutive recorded training days · \(strategy.recentHardDays) high-effort days this week")
                                .font(.system(size: 11))
                                .foregroundStyle(HCDesign.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(strategy.cues.prefix(2), id: \.self) { cue in
                                Label(cue, systemImage: "circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        IMUNEitanCheckInEditor()
                    }
    }

}

/// Brief private athlete check-in: complements physiological monitoring.
private struct IMUNEitanCheckInEditor: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @State private var expanded = false
    @State private var energy = 3
    @State private var soreness = 2
    @State private var stress = 2
    @State private var motivation = 3
    @State private var painOrIllness = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 9) {
                Stepper("Energy \(energy)/5", value: $energy, in: 1...5)
                Stepper("Soreness \(soreness)/5", value: $soreness, in: 1...5)
                Stepper("Stress \(stress)/5", value: $stress, in: 1...5)
                Stepper("Motivation \(motivation)/5", value: $motivation, in: 1...5)
                Toggle("Pain or illness affecting training", isOn: $painOrIllness)
                    .tint(HCDesign.electric)
                Button {
                    coach.recordEitanCheckIn(
                        energy: energy, soreness: soreness, stress: stress,
                        motivation: motivation, painOrIllness: painOrIllness)
                    expanded = false
                } label: {
                    Label("Save today's check-in", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(HCDesign.electric)
            }
            .font(.system(size: 12))
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: "figure.mind.and.body")
                Text(coach.todayEitanCheckIn == nil
                    ? "How are you feeling today?" : "Update today's check-in")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if coach.todayEitanCheckIn != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HCDesign.electric)
                }
            }
        }
        .tint(HCDesign.electric)
        .onAppear {
            guard let entry = coach.todayEitanCheckIn else { return }
            energy = entry.energy
            soreness = entry.soreness
            stress = entry.stress
            motivation = entry.motivation
            painOrIllness = entry.painOrIllness
        }
    }
}

// A single always-available session affordance outside the scrolling tabs.
// A tap navigates to the existing detailed workout, preserving the same
// phone/Watch reconciliation and logging paths.
private struct IMUNActiveWorkoutMiniBar: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @AppStorage("hcSelectedTab") private var selectedTab = "today"
    @AppStorage("hcTrainingActivity") private var activity = "weightlifting"

    var body: some View {
        Button {
            activity = "weightlifting"
            selectedTab = "training"
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(HCDesign.electric)
                VStack(alignment: .leading, spacing: 3) {
                    Text(coach.workout?.title ?? "Workout in progress")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(HCDesign.ink)
                    if let rest = coach.phoneRestEndsAt, rest > Date() {
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            Text(timeline.date < rest ?
                                 "Rest · " + hcDuration(rest.timeIntervalSince(timeline.date)) :
                                 "Rest finished")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(HCDesign.electric)
                        }
                    } else {
                        Text(coach.phoneSessionStartedAt == nil ?
                             "Active workout · tap to continue" :
                             "Tap to return to your workout")
                            .font(.system(size: 10))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                Spacer(minLength: 4)
                if let started = coach.activeWorkoutStartedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { now in
                        Text(hcDuration(now.date.timeIntervalSince(started)))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(HCDesign.ink)
                    }
                }
                if coach.phoneRestEndsAt != nil {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(HCDesign.electric)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(HCDesign.electric)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(HCDesign.card, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15)
                        .strokeBorder(HCDesign.electric.opacity(0.45), lineWidth: 1))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume active strength workout")
    }
}

private struct IMUNTodaysHealthStat: View {
    let label: String
    let metric: HCHealthMetric?
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(HCDesign.label(9))
                .foregroundStyle(HCDesign.secondary)
            Text(metric?.value ?? "—")
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.55)
            Text(metric.map { $0.source + " · " + $0.date } ?? "No reading")
                .font(.system(size: 9))
                .foregroundStyle(HCDesign.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(10)
        .background(HCDesign.card, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Health Coach 2.0 navigation

struct PremiumHomeView: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    // The app entry point owns this instance, so it survives tab changes.
    @EnvironmentObject private var appleHealth: HCAppleHealthReader
    @StateObject private var runImporter = HCRunHealthImporter()
    @StateObject private var tredictImporter = HCTredictImporter()
    @StateObject private var tredictPlans = HCTredictWatchPlanSync()
    @AppStorage("hcSelectedTab") private var selectedTab = "today"
    @AppStorage("hcTrainingActivity") private var visibleTrainingActivity = "weightlifting"
    @AppStorage("hcSelectedHealthCategory") private var visibleHealthCategory = "Overview"
    @AppStorage("hcSelectedHealthMetric") private var visibleHealthMetric = ""
    @State private var isIsaiahPresented = false
    @State private var isaiahLaunchContext = ""
    @AppStorage("hcAccentStyle") private var accentStyle = "crimson"
    @AppStorage("hcDesignPreset") private var designPreset = "techno"
    @AppStorage("hcDesignMode") private var designMode = "dark"
    @AppStorage("hcDesignCustomPalette") private var customPalette = false
    @AppStorage("hcDesignAccentHex") private var designAccentHex = "D4324F"
    @AppStorage("hcDesignBackgroundHex") private var designBackgroundHex = "070C16"
    @AppStorage("hcDesignSurfaceHex") private var designSurfaceHex = "212831"
    @AppStorage("hcDesignTextHex") private var designTextHex = "F6F3E9"
    @AppStorage("hcDesignShape") private var designCardShape = "rounded"
    @AppStorage("hcDesignFont") private var designFont = "standard"
    @AppStorage("hcDesignCustomGeometry") private var designCustomGeometry = false
    @AppStorage("hcWidgetShareHealth") private var shareWidgetHealth = false
    @AppStorage("hcLiveActivitiesEnabled") private var enableLiveActivities = true
    @AppStorage("hcEitanEnabled") private var eitanEnabled = true
    @AppStorage("hcEitanUseHealth") private var eitanUseHealth = true
    @AppStorage("hcEitanCloudSyncEnabled") private var eitanCloudConsent = false
    @AppStorage("hcEitanCoachingEnabled") private var eitanCoachingEnabled = true
    @AppStorage("hcEitanCoachStyle") private var eitanCoachStyle = "driven"
    @AppStorage("hcEitanPrimaryWearable") private var eitanSource = "Auto"
    @Environment(\.scenePhase) private var scenePhase
    private let scheduleRefresh = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    // Network polling should never be a 15-second render interruption on Health/Progress.
    private let progressRefresh = Timer.publish(every: 6, on: .main, in: .common).autoconnect()
    @State private var lastProgressCloudCheck = Date.distantPast
    @State private var lastRunHistoryCloudCheck = Date.distantPast

    // A single observer covers all styling tokens. Chaining a dozen
    // separate .onChange modifiers exceeded SwiftUI's type-check budget.
    private var designSignature: String {
        [designPreset, designMode, String(customPalette),
         designAccentHex, designBackgroundHex, designSurfaceHex,
         designTextHex, designCardShape, designFont,
         String(designCustomGeometry)].joined(separator: "|")
    }

    // Snapshot of visible app context. No health measurements are included here.
    private var screenContext: String {
        var details = ["Screen: " + selectedTab.capitalized,
                       "Date: " + HCPlanBuilder.dateString(Date())]
        switch selectedTab {
        case "today":
            details.append("Today: synced plan, health and active session")
        case "training":
            details.append("Activity: " + visibleTrainingActivity)
            if visibleTrainingActivity == "run", let plan = coach.runPlan {
                details.append("Selected run: " + plan.title + " [ID: " + plan.id + "]")
            } else if let plan = coach.workout {
                details.append("Selected strength workout: " + plan.title +
                               " [ID: " + plan.id + "]")
                details.append("Exercises: " +
                               plan.exercises.prefix(16).map(\.name).joined(separator: ", "))
                if coach.phoneSessionStartedAt != nil {
                    details.append("An iPhone strength session is currently active")
                }
                if let activeID = coach.phoneSetExerciseID,
                   let activeExercise = plan.exercises.first(where: { $0.id == activeID }) {
                    details.append("Active strength set: " + activeExercise.name)
                }
            }
        case "health":
            details.append("Health category: " + visibleHealthCategory)
            if !visibleHealthMetric.isEmpty {
                details.append("Selected metric: " + visibleHealthMetric)
            }
            details.append("Health measurements are opt-in, not included in screen context")
        case "progress":
            details.append("Showing recorded progress and training history")
        case "settings":
            details.append("Showing appearance, sync and integration settings")
        default: break
        }
        return details.joined(separator: "\n")
    }

    private func presentIsaiah() {
        isaiahLaunchContext = screenContext
        isIsaiahPresented = true
    }

    private func migratePreviousHealthSourceChoice() {
        let preferences = UserDefaults.standard
        guard preferences.object(forKey: "hcEitanPrimaryWearable") == nil else { return }
        let previous = preferences.string(forKey: "hcPreferredHealthSource") ?? "Auto"
        if HCEitanWearableSource.choices.contains(previous) {
            preferences.set(previous, forKey: "hcEitanPrimaryWearable")
        }
    }

    private func updateEitan() {
        guard eitanEnabled && eitanUseHealth else {
            coach.updateEitan(nil)
            return
        }
        coach.updateEitan(IMUNEitanWellnessEngine.evaluate(
            health: appleHealth, coach: coach, preferredSource: eitanSource))
    }

    private func publishWidgets() {
        IMUNWidgetPublisher.publish(coach: coach,
                                    health: appleHealth,
                                    allowHealth: shareWidgetHealth)
    }
    private func updateLiveWorkout() {
        IMUNLiveWorkoutController.synchronize(coach: coach,
                                             enabled: enableLiveActivities)
    }

    private var navigationShell: AnyView {
        AnyView(TabView(selection: $selectedTab) {
            NavigationStack { IMUNTodayPage(appleHealth: appleHealth, openCoach: presentIsaiah) }
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag("today")
            NavigationStack { PremiumTrainingPage() }
                .tabItem { Label("Training", systemImage: "figure.run.circle.fill") }
                .tag("training")
            NavigationStack { PremiumProgressPage() }
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
                .tag("progress")
            NavigationStack { PremiumRecoveryPage(appleHealth: appleHealth) }
                .tabItem { Label("Health", systemImage: "heart.text.square.fill") }
                .tag("health")
            NavigationStack { PremiumSettingsPage(appleHealth: appleHealth) }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag("settings")
        }
        .tint(HCDesign.electric)
        .preferredColorScheme(IMUNStyle.preferredScheme)
        .environmentObject(runImporter)
        .environmentObject(tredictImporter)
        .environmentObject(tredictPlans)
        // All tabs must share the same Health reader. Sheets already receive it,
        // but a missing root injection used to crash Settings on launch.
        .environmentObject(appleHealth)
        .overlay(alignment: .bottom) {
            if coach.isWorkoutActive {
                IMUNActiveWorkoutMiniBar()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            IMUNIsaiahLauncherButton(glow: HCDesign.electric, action: presentIsaiah)
                .padding(.trailing, 18)
                .padding(.bottom, coach.isWorkoutActive ? 147 : 70)
        }
        .sheet(isPresented: $isIsaiahPresented) {
            NavigationStack {
                PremiumCoachConversation(launchContext: isaiahLaunchContext)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .environmentObject(coach)
            .environmentObject(appleHealth)
            .environmentObject(runImporter)
            .environmentObject(tredictImporter)
            .environmentObject(tredictPlans)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onOpenURL { url in
            guard url.scheme == "imun" else { return }
            let destination = url.host ?? ""
            if destination == "today" || destination == "training" ||
               destination == "health" || destination == "progress" {
                selectedTab = destination
            }
        }
        )
    }

    private var dataObservationShell: AnyView {
        AnyView(navigationShell
        .onReceive(coach.objectWillChange) { _ in
            // Publish after @Published has committed new values.
            DispatchQueue.main.async {
                publishWidgets()
                updateLiveWorkout()
            }
        }
        .onReceive(appleHealth.$metrics) { _ in
            DispatchQueue.main.async {
                publishWidgets()
                updateEitan()
            }
        }
        .onReceive(appleHealth.$metricHistory) { _ in
            DispatchQueue.main.async { updateEitan() }
        }
        .onReceive(coach.$recoveryHistory) { _ in
            DispatchQueue.main.async { updateEitan() }
        }
        .onReceive(coach.$trainingActivities) { _ in
            DispatchQueue.main.async { updateEitan() }
        }
        .onReceive(coach.$eitanCheckIns) { _ in
            DispatchQueue.main.async { updateEitan() }
        }
        .onChange(of: eitanCoachStyle) { _, _ in updateEitan() }
        .onChange(of: eitanEnabled) { _, _ in
            updateEitan()
            coach.sendEitanToWatch(forceQueue: true)
            coach.refreshEitanCloudSync(force: true)
        }
        .onChange(of: eitanUseHealth) { _, _ in
            updateEitan()
            coach.sendEitanToWatch(forceQueue: true)
            coach.refreshEitanCloudSync(force: true)
        }
        .onChange(of: eitanCloudConsent) { _, _ in
            coach.refreshEitanCloudSync(force: true)
        }
        .onChange(of: eitanCoachingEnabled) { _, _ in
            coach.sendEitanToWatch(forceQueue: true)
        }
        .onChange(of: eitanSource) { _, _ in
            updateEitan()
            coach.sendEitanToWatch()
        }
        )
    }

    private var preferencesShell: AnyView {
        AnyView(dataObservationShell
        .onChange(of: shareWidgetHealth) { _, _ in publishWidgets() }
        .onChange(of: enableLiveActivities) { _, _ in updateLiveWorkout() }
        .onChange(of: selectedTab) { _, tab in
            if tab == "progress" && coach.signedIn {
                coach.refreshCloudProgress()
            }
            if tab == "coach" {
                selectedTab = "training"
                presentIsaiah()
            }
        }
        )
    }

    var body: some View {
        preferencesShell
        .onReceive(tredictPlans.$runs) { coach.updateTredictScheduledRuns($0) }
        .onReceive(tredictPlans.$lastSentTodayRunID) { id in
            guard let id,
                  let selected = tredictPlans.runs.first(where: { $0.id == id }) else { return }
            coach.useTredictRunAsToday(selected)
        }
        .onReceive(tredictImporter.$snapshot) { snapshot in
            if snapshot.lastSync != nil {
                coach.updateTredictSnapshot(snapshot)
            }
        }
        .onReceive(runImporter.$runs) { imported in
            coach.updateHealthRuns(imported)
        }
        .onReceive(runImporter.$workouts) { imported in
            coach.updateHealthWorkouts(imported)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                runImporter.startIfAuthorized()
                if tredictPlans.connected { tredictPlans.refresh() }
                if coach.signedIn { coach.refresh(date: Date()) }
            }
        }
        .onReceive(progressRefresh) { _ in
            guard scenePhase == .active, coach.signedIn else { return }
            let now = Date()
            let activeInterval: TimeInterval = coach.isWorkoutActive ? 6 :
                (selectedTab == "training" || selectedTab == "today" ? 12 : 45)
            guard now.timeIntervalSince(lastProgressCloudCheck) >=
                    activeInterval else { return }
            lastProgressCloudCheck = now
            // Read cloud-authoritative UUID/undo records even if the
            // companion link is down. Pending local records remain visible.
            coach.refreshCloudProgress()
            coach.retryPendingCloudSets()
            let runInterval: TimeInterval = coach.isWorkoutActive ? 24 : 60
            if now.timeIntervalSince(lastRunHistoryCloudCheck) >= runInterval {
                lastRunHistoryCloudCheck = now
                coach.refreshCloudRunHistory()
            }
        }
        .onReceive(scheduleRefresh) { _ in
            // Poll the Command Center calendar while the iPhone app is open.
            // watchOS cannot independently invent or reschedule a session.
            if scenePhase == .active && coach.signedIn && !coach.loading {
                coach.refreshTodaySchedule()
            }
        }
        .onChange(of: accentStyle) { _, _ in
            configureTabAppearance()
            coach.sendToWatch()
        }
        .onChange(of: designSignature) { _, _ in configureTabAppearance() }
        .onAppear {
            migratePreviousHealthSourceChoice()
            runImporter.startIfAuthorized()
            if selectedTab == "coach" { selectedTab = "training" }
            if coach.signedIn && coach.workout == nil { coach.refresh(date: Date()) }
            if coach.signedIn {
                coach.refreshCloudProgress()
                coach.refreshCloudRunHistory(force: true)
            }
            configureTabAppearance()
            if tredictPlans.connected { tredictPlans.refresh() }
            publishWidgets()
            updateLiveWorkout()
            updateEitan()
        }
    }

    private func configureTabAppearance() {
        let bar = UITabBarAppearance()
        if IMUNStyle.navigation == "editorial" {
            // Light, translucent tab rail for Atelier / editorial layouts.
            bar.configureWithDefaultBackground()
            bar.backgroundColor = UIColor(HCDesign.canvas).withAlphaComponent(0.78)
            bar.shadowColor = .clear
        } else {
            bar.configureWithOpaqueBackground()
            bar.backgroundColor = IMUNStyle.navigation == "sport"
                ? UIColor(HCDesign.electric).withAlphaComponent(0.16)
                : UIColor(HCDesign.canvas)
        }
        bar.stackedLayoutAppearance.normal.iconColor = UIColor(HCDesign.secondary)
        bar.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(HCDesign.secondary)]
        bar.stackedLayoutAppearance.selected.iconColor = UIColor(HCDesign.electric)
        bar.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(HCDesign.electric)]
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar
    }
}


// One Training destination. The picker controls the sport, not the daily plan:
// each activity still reads its date-matched workout from the iPhone calendar.
/// Tracks only this tab's content offset, not the root screen position.
private struct IMUNTrainingScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct IMUNTrainingScrollProbe: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: IMUNTrainingScrollKey.self,
                value: geometry.frame(in: .named("imunTrainingScroll")).minY)
        }
        .frame(height: 0)
        .accessibilityHidden(true)
    }
}

private struct PremiumTrainingPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @AppStorage("hcTrainingActivity") private var chosenActivity = "weightlifting"
    @State private var activityPickerExpanded = false
    @State private var headerCollapsed = false

    private var selected: IMUNTrainingActivity {
        IMUNTrainingActivity(rawValue: chosenActivity) ?? .weightlifting
    }

    private var plannedTitle: String {
        let today = HCPlanBuilder.dateString(Date())
        switch selected {
        case .run:
            return coach.runPlan?.date == today
                ? (coach.runPlan?.title ?? "No run planned")
                : "No run planned today"
        case .weightlifting:
            return coach.workout?.date == today
                ? (coach.workout?.title ?? "No lift planned")
                : "No lift planned today"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: headerCollapsed ? 3 : 9) {
                if !headerCollapsed {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("IMUN / TRAINING")
                                .font(HCDesign.label(9))
                                .tracking(1.5)
                                .foregroundStyle(HCDesign.aqua)
                            Text("Training")
                                .font(HCDesign.display(25))
                                .foregroundStyle(HCDesign.ink)
                        }
                        Spacer()
                        Text(Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(HCDesign.label(11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        activityPickerExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selected.symbol)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(HCDesign.electric)
                            .frame(width: 34, height: 34)
                            .background(HCDesign.electric.opacity(0.13),
                                        in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(HCDesign.ink)
                            Text(plannedTitle)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                                .foregroundStyle(HCDesign.secondary)
                        }
                        Spacer(minLength: 8)
                        Text("CHANGE")
                            .font(HCDesign.label(9))
                            .tracking(0.5)
                            .foregroundStyle(HCDesign.aqua)
                        Image(systemName: activityPickerExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(HCDesign.aqua)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, headerCollapsed ? 5 : 9)
                    .background(HCDesign.card,
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(HCDesign.outline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Selected activity \(selected.title). Tap to change.")

                if activityPickerExpanded {
                    HStack(spacing: 9) {
                        ForEach(IMUNTrainingActivity.allCases) { activity in
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    chosenActivity = activity.rawValue
                                    activityPickerExpanded = false
                                }
                            } label: {
                                Label(activity.title, systemImage: activity.symbol)
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(selected == activity ?
                                        HCDesign.onAccent : HCDesign.ink)
                                    .background(selected == activity ?
                                        HCDesign.electric : HCDesign.raised,
                                        in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, headerCollapsed ? 4 : 8)
            .padding(.bottom, headerCollapsed ? 5 : 10)
            .animation(IMUNStyle.animationsEnabled ? .easeOut(duration: 0.19) : nil,
                       value: headerCollapsed)

            Rectangle()
                .fill(HCDesign.outline.opacity(0.65))
                .frame(height: 1)

            Group {
                switch selected {
                case .run: PremiumRunPage(headerCollapsed: $headerCollapsed)
                case .weightlifting: PremiumStrengthPage(headerCollapsed: $headerCollapsed)
                }
            }
        }
        .hcPage()
        // Match the other tabs: large in-content title scrolls away; the
        // native compact title replaces it once Training has collapsed.
        .navigationTitle(headerCollapsed ? "Training" : "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PremiumHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var badge: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(eyebrow.uppercased())
                    .font(HCDesign.label())
                    .tracking(1.1)
                    .foregroundStyle(HCDesign.aqua)
                Spacer()
                if let badge { HCAccentTag(title: badge) }
            }
            Text(title)
                .font(HCDesign.display(32))
                .tracking(-0.5)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .foregroundStyle(HCDesign.ink)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HCDesign.secondary)
        }
        .padding(.top, 13)
    }
}

private struct PremiumLogin: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        HCCard(accent: HCDesign.aqua) {
            VStack(alignment: .leading, spacing: 15) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(HCDesign.aqua)
                Text("WELCOME TO IMUN")
                    .font(HCDesign.display(21))
                Text("Sign in to access your training, history and personal coaching.")
                    .font(.subheadline)
                    .foregroundStyle(HCDesign.secondary)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(HCDesign.raised, in: RoundedRectangle(cornerRadius: 12))
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding(14)
                    .background(HCDesign.raised, in: RoundedRectangle(cornerRadius: 12))
                HCFilledButton(title: "Connect Health Coach", icon: "arrow.right",
                               disabled: email.isEmpty || password.isEmpty || coach.loading) {
                    coach.login(email: email, password: password, date: Date())
                    password = ""
                }
                Text(coach.status).font(.caption2).foregroundStyle(HCDesign.secondary)
            }
        }
    }
}

/// Content is independent from the selected theme. The athlete explicitly
/// opts in in Settings → Motivation; otherwise training remains distraction-free.
private struct IMUNTrainingMindsetCard: View {
    @AppStorage("hcMotivationShowTraining") private var show = false
    @AppStorage("hcMotivationSource") private var source = "off"
    @AppStorage("hcMotivationCustom") private var custom = ""
    @AppStorage("hcMotivationTranslation") private var translation = "ESV"

    var body: some View {
        if show, source != "off", let line = IMUNMotivation.line {
            HCCard {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        Image(systemName: source == "scripture" ? "book.closed" : "bookmark")
                            .foregroundStyle(HCDesign.aqua)
                        Text("WORDS TO TRAIN BY")
                            .font(HCDesign.label(10))
                            .tracking(1.2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                    Text(line)
                        .font(.system(size: 16, weight: .medium,
                                      design: IMUNStyle.headingDesign))
                        .foregroundStyle(HCDesign.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct PremiumStrengthPage: View {
    @Binding var headerCollapsed: Bool
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    private var date: Date { Date() }
    @State private var movingSession: HCPlannedSession?
    @AppStorage("hcAggressiveProgression") private var aggressive = true
    @State private var showEditor = false
    @State private var confirmUndoWorkout = false
    @State private var showNew = false
    @State private var newTitle = "Full Body Strength"

    private var plan: HCWorkout? { coach.workout }
    private var doneSets: [HCLoggedSet] {
        guard let plan else { return [] }
        return coach.completedSets(for: plan)
    }
    private var volume: Double {
        doneSets.reduce(0) { $0 + ($1.weightLb ?? 0) * Double($1.reps) }
    }

    var body: some View {
        ScrollView {
            IMUNTrainingScrollProbe()
            VStack(alignment: .leading, spacing: 19) {
                HCSectionTitle(title: "Weightlifting", detail: aggressive ? "Coached session" : "Today's plan")
                IMUNTrainingMindsetCard()
                if !coach.signedIn { PremiumLogin() }

                if let plan {
                    HCCard(accent: HCDesign.electric) {
                        VStack(alignment: .leading, spacing: 17) {
                            HCAccentTag(title: "TODAY'S PROGRAM", color: HCDesign.electric)
                            HStack(alignment: .center, spacing: 18) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(plan.title)
                                        .font(HCDesign.display(25))
                                        .tracking(-0.7)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("\(plan.exercises.count) movements · \(plan.prescribedSetCount) working sets")
                                        .font(.subheadline).foregroundStyle(HCDesign.secondary)
                                }
                                Spacer(minLength: 0)
                                IMUNThemeProgressView(
                                    completed: doneSets.count,
                                    planned: plan.prescribedSetCount,
                                    compact: true)
                            }

                            HStack(spacing: 7) {
                                HCMetricBlock(label: "Sets logged",
                                              value: "\(doneSets.count)/\(plan.prescribedSetCount)",
                                              tint: HCDesign.electric)
                                HCMetricBlock(label: "Volume",
                                              value: volume.formatted(.number.precision(.fractionLength(0))) + " lb")
                                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                    HCMetricBlock(label: "Elapsed",
                                                  value: hcDuration(coach.phoneSessionStartedAt.map {
                                                      timeline.date.timeIntervalSince($0)
                                                  } ?? 0))
                                }
                            }
                            if doneSets.count >= plan.prescribedSetCount &&
                               plan.prescribedSetCount > 0 &&
                               coach.phoneSessionStartedAt == nil {
                                IMUNThemeCompletionCallout()
                            } else if coach.phoneSessionStartedAt == nil {
                                HCFilledButton(
                                    title: coach.activeWatchStartedAt != nil ?
                                        "CONTINUE FROM WATCH" : "START WORKOUT",
                                    icon: "play.fill") {
                                    coach.startPhoneWorkout()
                                }
                            } else {
                                HCOutlineButton(title: "Finish workout", icon: "stop.fill") {
                                    coach.finishPhoneWorkout()
                                }
                                HCOutlineButton(title: "Undo Workout",
                                                icon: "arrow.uturn.backward") {
                                    confirmUndoWorkout = true
                                }
                            }
                            HStack(spacing: 10) {
                                HCOutlineButton(title: "Edit program", icon: "slider.horizontal.3") {
                                    showEditor = true
                                }
                                HCOutlineButton(title: "Send to watch", icon: "applewatch") {
                                    coach.sendToWatch()
                                }
                            }
                            if let entry = coach.plannedSessions.first(where: {
                                $0.date == HCPlanBuilder.dateString(date) &&
                                     ($0.kind == "lift" || $0.kind == "lift-template")
                            }) {
                                HCOutlineButton(title: "Move this workout", icon: "calendar.badge.clock") {
                                    movingSession = entry
                                }
                            }
                        }
                    }
                    HCSectionTitle(title: "Workout lineup", detail: "Tap to train")
                    ForEach(plan.exercises.indices, id: \.self) { index in
                        let exercise = plan.exercises[index]
                        NavigationLink {
                            PremiumExerciseSession(exerciseID: exercise.id)
                        } label: {
                            PremiumExerciseCard(index: index + 1, exercise: exercise,
                                                workoutDate: plan.date,
                                                logged: doneSets.filter { $0.exerciseID == exercise.id },
                                                aggressive: aggressive)
                        }
                        .buttonStyle(.plain)
                    }
                    HCOutlineButton(title: "Add or rearrange exercises", icon: "plus") {
                        showEditor = true
                    }
                } else {
                    HCCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.largeTitle).foregroundStyle(HCDesign.electric)
                            Text("No strength session planned")
                                .font(HCDesign.display(23))
                            Text("Create a session for today, or move an upcoming one here from Progress.")
                                .font(.subheadline).foregroundStyle(HCDesign.secondary)
                            HCFilledButton(title: "CREATE WORKOUT", icon: "plus") {
                                showNew = true
                            }
                        }
                    }
                }
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 18)
        }
        .coordinateSpace(name: "imunTrainingScroll")
        .onPreferenceChange(IMUNTrainingScrollKey.self) { offset in
            // Hysteresis stops a collapsing header from bouncing repeatedly
            // at the exact scroll threshold while the page is dragged.
            if offset < -95 && !headerCollapsed {
                headerCollapsed = true
            } else if offset > -25 && headerCollapsed {
                headerCollapsed = false
            }
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $movingSession) { entry in
            IMUNMoveWorkoutSheet(entry: entry)
                .environmentObject(coach)
        }
        .sheet(isPresented: $showEditor) {
            PremiumWorkoutEditor()
                .environmentObject(coach)
        }
        .confirmationDialog("Undo Workout?", isPresented: $confirmUndoWorkout,
                            titleVisibility: .visible) {
            Button("Undo Workout", role: .destructive) {
                coach.undoPhoneWorkout()
            }
            Button("Keep Workout", role: .cancel) {}
        } message: {
            Text("This reverses the active session and its logged sets. Your prescribed workout stays available.")
        }
        .alert("New training session", isPresented: $showNew) {
            TextField("Workout title", text: $newTitle)
            Button("Create") { coach.newWorkout(date: date, title: newTitle) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct PremiumExerciseCard: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    let index: Int
    let exercise: HCExercise
    let workoutDate: String
    let logged: [HCLoggedSet]
    let aggressive: Bool

    var body: some View {
        let recommendation = coach.suggestion(for: exercise, on: workoutDate, aggressive: aggressive)
        HCCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 11) {
                    Text(String(format: "%02d", index))
                        .font(HCDesign.metric(18))
                        .foregroundStyle(HCDesign.electric)
                        .frame(width: 35, alignment: .leading)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(exercise.name)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(HCDesign.ink)
                        Text("\(exercise.prescribedSets) sets  ·  \(exercise.repDescription) reps  ·  \(exercise.restSeconds)s rest")
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(HCDesign.secondary)
                }
                Rectangle().fill(HCDesign.outline.opacity(0.65)).frame(height: 1)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("COACH LOAD")
                            .font(HCDesign.label(10)).tracking(1)
                            .foregroundStyle(HCDesign.secondary)
                        if let weight = exercise.suggestedWeightLb ?? recommendation.weightLb {
                            Text(weight.formatted() + (recommendation.perDumbbell ? " / DB" : " lb"))
                                .font(HCDesign.metric(21))
                                .foregroundStyle(HCDesign.electric)
                        } else {
                            Text("Set a baseline")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(HCDesign.ink)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        HCAccentTag(title: recommendation.confidence,
                                    color: recommendation.confidence == "High" ?
                                    HCDesign.electric : HCDesign.aqua)
                        Text("\(logged.count) / \(exercise.prescribedSets) completed")
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Workout builder and set controls

/// Purpose-built iMun workout composition surface. No stock edit-mode list,
/// delete swipe affordances, or unranked workout substitution sheets.
private struct PremiumWorkoutEditor: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Environment(\.dismiss) private var dismiss
    @State private var library = false
    @State private var workoutName = ""
    @State private var smartSwapExercise: HCExercise?
    @State private var pendingRemoval: HCExercise?
    @State private var actionStatus: String?

    private var plan: HCWorkout? { coach.workout }

    private func completed(_ exercise: HCExercise) -> Bool {
        guard let plan else { return false }
        return coach.completedSets(for: plan).contains { $0.exerciseID == exercise.id }
    }

    private func save(title: String, list: [HCExercise]) {
        guard let plan else { return }
        // Stable IDs, reindexed layout. A moved exercise keeps its prescribed
        // sets and historical source attribution.
        let ordered = list.enumerated().map { index, old -> HCExercise in
            var next = HCExercise(
                id: old.id, name: old.name, originalName: old.originalName,
                exerciseIndex: index, prescribedSets: old.prescribedSets,
                repMin: old.repMin, repMax: old.repMax,
                suggestedWeightLb: old.suggestedWeightLb,
                restSeconds: old.restSeconds)
            next.instructions = old.instructions
            next.movementType = old.movementType
            return next
        }
        coach.saveEditedWorkout(HCWorkout(
            id: plan.id, date: plan.date, sessionKey: plan.sessionKey,
            title: title, exercises: ordered, isPreview: false))
    }

    private func move(_ exercise: HCExercise, by shift: Int) {
        guard let plan,
              let index = plan.exercises.firstIndex(where: { $0.id == exercise.id }),
              plan.exercises.indices.contains(index + shift) else { return }
        var list = plan.exercises
        list.swapAt(index, index + shift)
        save(title: plan.title, list: list)
    }

    private func remove(_ exercise: HCExercise) {
        guard let plan else { return }
        guard !completed(exercise) && coach.phoneSetExerciseID != exercise.id else {
            actionStatus = "Recorded or active movements cannot be deleted. Undo the current set first."
            return
        }
        save(title: plan.title, list: plan.exercises.filter { $0.id != exercise.id })
    }

    private func replace(_ original: HCExercise, with item: HCLibraryExercise) {
        guard let plan, let index = plan.exercises.firstIndex(where: { $0.id == original.id }) else {
            return
        }
        guard !completed(original) && coach.phoneSetExerciseID != original.id else {
            actionStatus = "This movement already has recorded or active sets. Undo the current sets before swapping."
            return
        }
        let oldRounds = original.isUnilateral ?
            max(1, original.prescribedSets / 2) : original.prescribedSets
        let slots = item.isUnilateral ? min(24, oldRounds * 2) : min(12, oldRounds)
        let probe = HCExercise(id: original.id, name: item.name,
            originalName: item.name, exerciseIndex: original.exerciseIndex,
            prescribedSets: slots, repMin: original.repMin,
            repMax: original.repMax, suggestedWeightLb: nil,
            restSeconds: original.restSeconds)
        let suggestion = coach.suggestion(for: probe, on: plan.date)
        var swapped = HCExercise(id: original.id, name: item.name,
            originalName: item.name, exerciseIndex: original.exerciseIndex,
            prescribedSets: slots, repMin: original.repMin, repMax: original.repMax,
            suggestedWeightLb: suggestion.weightLb, restSeconds: original.restSeconds)
        swapped.instructions = item.instructions
        var list = plan.exercises
        list[index] = swapped
        save(title: plan.title, list: list)
    }

    private func add(_ item: HCLibraryExercise) {
        guard let plan, plan.exercises.count < 35 else { return }
        let index = plan.exercises.count
        let slots = item.isUnilateral ? 6 : 3
        let probe = HCExercise(id: UUID().uuidString, name: item.name,
            originalName: item.name, exerciseIndex: index,
            prescribedSets: slots, repMin: 8, repMax: 12,
            suggestedWeightLb: nil, restSeconds: 120)
        let suggestion = coach.suggestion(for: probe, on: plan.date)
        var added = HCExercise(id: probe.id, name: item.name,
            originalName: item.name, exerciseIndex: index,
            prescribedSets: slots, repMin: 8, repMax: 12,
            suggestedWeightLb: suggestion.weightLb, restSeconds: 120)
        added.instructions = item.instructions
        save(title: plan.title, list: plan.exercises + [added])
    }

    private func exerciseCard(_ exercise: HCExercise, position: Int,
                              total: Int) -> some View {
        HCCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Text(String(format: "%02d", position + 1))
                        .font(HCDesign.metric(19))
                        .foregroundStyle(HCDesign.electric)
                        .frame(width: 35, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(HCDesign.ink)
                        Text(exercise.setSummary + "  ·  " +
                             exercise.repDescription + " reps")
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Button { move(exercise, by: -1) } label: {
                            Image(systemName: "chevron.up")
                                .frame(width: 30, height: 26)
                        }
                        .disabled(position == 0)
                        Button { move(exercise, by: 1) } label: {
                            Image(systemName: "chevron.down")
                                .frame(width: 30, height: 26)
                        }
                        .disabled(position >= total - 1)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HCDesign.secondary)
                    .buttonStyle(.plain)
                }
                Rectangle().fill(HCDesign.outline).frame(height: 1)
                HStack(spacing: 8) {
                    Button {
                        smartSwapExercise = exercise
                    } label: {
                        Label("SMART SWAP", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .foregroundStyle(HCDesign.canvas)
                            .background(HCDesign.electric, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        StrengthExerciseDetails(exerciseID: exercise.id)
                    } label: {
                        Label("EDIT", systemImage: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(HCDesign.aqua)
                            .padding(10)
                    }
                    Spacer(minLength: 2)
                    Button {
                        pendingRemoval = exercise
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                            .frame(width: 31, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove " + exercise.name)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WORKOUT STUDIO")
                            .font(.system(size: 25, weight: .heavy, design: .rounded))
                            .foregroundStyle(HCDesign.ink)
                        Text("Build, rearrange and intelligently substitute movements.")
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    HCCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SESSION NAME")
                                .font(HCDesign.label(10))
                                .foregroundStyle(HCDesign.secondary)
                            TextField("Workout name", text: $workoutName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(HCDesign.ink)
                                .tint(HCDesign.electric)
                            HCFilledButton(title: "SAVE SESSION NAME",
                                           icon: "checkmark") {
                                guard let plan,
                                      !workoutName.trimmingCharacters(in: .whitespaces).isEmpty else {
                                    return
                                }
                                save(title: workoutName, list: plan.exercises)
                            }
                        }
                    }
                    if let plan {
                        HCSectionTitle(title: "Movement sequence",
                                       detail: "\(plan.exercises.count) movements · \(plan.prescribedSetCount) work sets")
                        ForEach(plan.exercises) { exercise in
                            exerciseCard(exercise,
                                position: plan.exercises.firstIndex(where: {
                                    $0.id == exercise.id
                                }) ?? 0,
                                total: plan.exercises.count)
                        }
                    }
                    HCFilledButton(title: "ADD MOVEMENT",
                                   icon: "plus.circle.fill") {
                        library = true
                    }
                    if let actionStatus {
                        Text(actionStatus)
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.aqua)
                    }
                }
                .padding(18)
            }
            .background(HCDesign.canvas.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("DONE") { dismiss() }
                        .foregroundStyle(HCDesign.electric)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $library) {
            ExerciseLibraryPicker { item in add(item) }
        }
        .sheet(item: $smartSwapExercise) { original in
            ExerciseLibraryPicker(replacing: original) { item in
                replace(original, with: item)
            }
        }
        .confirmationDialog("REMOVE MOVEMENT?",
                            isPresented: Binding(get: { pendingRemoval != nil },
                                                 set: { if !$0 { pendingRemoval = nil } })) {
            Button("Remove exercise", role: .destructive) {
                if let pendingRemoval { remove(pendingRemoval) }
                pendingRemoval = nil
            }
            Button("Keep exercise", role: .cancel) {
                pendingRemoval = nil
            }
        } message: {
            Text("This removes the exercise from the current workout plan.")
        }
        .onAppear { workoutName = coach.workout?.title ?? "" }
    }
}

/// Source-attributed, wrist-specific coaching signals. Values are relative
/// movement proxies; no anatomical ROM, bar velocity or measured watts.
private struct IMUNSetMotionInsights: View {
    let insight: HCMotionSetInsight

    private func stat(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(HCDesign.secondary)
            Text(value)
                .font(HCDesign.metric(17))
                .foregroundStyle(HCDesign.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(HCDesign.canvas.opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 11))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("MOTION INTELLIGENCE", systemImage: "waveform.path")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(HCDesign.aqua)
                Spacer()
                Text(insight.source + " · " +
                    (insight.wearableLocation
                        .flatMap(IMUNWearableLocation.init(rawValue:))?.title ??
                        insight.wearSide.capitalized + " wrist"))
                    .font(.system(size: 10))
                    .foregroundStyle(HCDesign.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: 8) {
                stat("Detected cycles", "\(insight.detectedReps)")
                if let seconds = insight.averageCycleSeconds {
                    stat("Avg cycle", String(format: "%.2f s", seconds))
                }
                if let speed = insight.peakWristRotationDegreesPerSecond {
                    stat("Peak wrist rotation", String(format: "%.0f°/s", speed))
                }
                if let score = insight.repTempoConsistencyPercent {
                    stat("Tempo consistency", String(format: "%.0f%% proxy", score))
                }
                if let score = insight.wristMotionConsistencyScore {
                    stat("Wrist consistency", String(format: "%.0f%% proxy", score))
                }
                if let travel = insight.meanWristRotationDegrees {
                    stat("Rotational travel", String(format: "%.0f° proxy", travel))
                }
                if let index = insight.relativeMotionIntensityIndex {
                    stat("Motion intensity", String(format: "%.1f relative", index))
                }
                if let peak = insight.peakLinearAccelerationG {
                    stat("Peak wrist acceleration", String(format: "%.2f g", peak))
                }
                if let percent = insight.sampleCoveragePercent {
                    stat("Signal coverage", String(format: "%.0f%%", percent))
                }
                if let gaps = insight.samplingGapCount {
                    stat("Sensor gaps", String(gaps))
                }
                if let delay = insight.lastCycleSlowdownPercent,
                   delay.isFinite {
                    stat("Final cycle tempo", String(format: "%+.0f%%", delay))
                }
                if let change = insight.lastWristRotationChangePercent,
                   change.isFinite {
                    stat("Final wrist travel", String(format: "%+.0f%%", change))
                }
                if let active = insight.repActivePhaseSeconds,
                   !active.isEmpty {
                    stat("Active-phase avg",
                         String(format: "%.2f s",
                                active.reduce(0, +) / Double(active.count)))
                }
            }
            if let cycles = insight.cycleSeconds, cycles.count >= 3 {
                VStack(alignment: .leading, spacing: 5) {
                    Text("DETECTED CYCLE TEMPO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(HCDesign.secondary)
                    Chart(Array(cycles.indices), id: \.self) { index in
                        LineMark(x: .value("Cycle", index + 1),
                                 y: .value("Seconds", cycles[index]))
                            .foregroundStyle(HCDesign.electric)
                    }
                    .frame(height: 112)
                    .accessibilityLabel("Wrist-motion cycle duration over this set")
                }
            }
            if let rotation = insight.cycleWristRotationDegrees,
               rotation.count >= 3 {
                VStack(alignment: .leading, spacing: 5) {
                    Text("RELATIVE WRIST ROTATION · PER CYCLE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(HCDesign.secondary)
                    Chart(Array(rotation.indices), id: \.self) { index in
                        LineMark(x: .value("Cycle", index + 1),
                                 y: .value("Rotational travel", rotation[index]))
                            .foregroundStyle(HCDesign.aqua)
                    }
                    .frame(height: 105)
                    Text("Integrated wrist rotation, not the range of any joint or the dumbbell path.")
                        .font(.system(size: 10))
                        .foregroundStyle(HCDesign.secondary)
                }
            }
            if let accel = insight.repAccelerationPeaksG,
               accel.count >= 3 {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ACCELERATION · DETECTED CYCLES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(HCDesign.secondary)
                    Chart(Array(accel.indices), id: \.self) { index in
                        BarMark(x: .value("Cycle", index + 1),
                                y: .value("Wrist acceleration", accel[index]))
                            .foregroundStyle(HCDesign.electric)
                    }
                    .frame(height: 90)
                }
            }
            if let confidence = insight.analysisConfidence {
                HStack(spacing: 7) {
                    Image(systemName: confidence == "Low" ?
                          "exclamationmark.triangle" : "checkmark.shield")
                    Text("Capture confidence: " + confidence)
                    Spacer(minLength: 0)
                    if let version = insight.motionModelVersion {
                        Text("MODEL \(version)")
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HCDesign.aqua)
            }
            if let warnings = insight.analysisWarnings, !warnings.isEmpty {
                Text("Sensor quality: " + warnings.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
            }
            Text(insight.note)
                .font(.system(size: 12))
                .foregroundStyle(HCDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Experimental. Wrist motion is not directly measured joint range, dumbbell speed, force, power, or a verified form assessment.")
                .font(.system(size: 10))
                .foregroundStyle(HCDesign.secondary)
        }
    }
}

private struct PremiumExerciseSession: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @AppStorage("hcAggressiveProgression") private var aggressive = true
    let exerciseID: String
    @State private var hasWeight = false
    @State private var weight = 0.0
    @State private var reps = 8
    @State private var rir = 2
    @State private var workingSide: HCWorkingSide = .left
    @State private var smartSwapOpen = false
    @State private var swapError: String?

    private var ex: HCExercise? { coach.workout?.exercises.first { $0.id == exerciseID } }
    private var completed: [HCLoggedSet] {
        guard let p = coach.workout else { return [] }
        return coach.completedSets(for: p)
            .filter { $0.exerciseID == exerciseID }
    }
    private var active: Bool { coach.phoneSetExerciseID == exerciseID && coach.phoneSetStartedAt != nil }

    var body: some View {
        ScrollView {
            if let ex, let p = coach.workout {
                let suggested = coach.suggestion(for: ex, on: p.date, aggressive: aggressive)
                VStack(alignment: .leading, spacing: 18) {
                    PremiumHeader(eyebrow: "STRENGTH / EXERCISE",
                                  title: ex.name,
                                  subtitle: "\(ex.setSummary) · \(ex.repDescription) reps · \(ex.restSeconds)s rest")
                    HCCard(accent: HCDesign.aqua) {
                        VStack(alignment: .leading, spacing: 11) {
                            HCAccentTag(title: "INTELLIGENT TARGET", color: HCDesign.aqua)
                            HStack(alignment: .firstTextBaseline) {
                                Text((ex.suggestedWeightLb ?? suggested.weightLb)?.formatted() ?? "—")
                                    .font(HCDesign.display(42))
                                    .foregroundStyle(HCDesign.electric)
                                Text(suggested.perDumbbell ? "lb per dumbbell" : "lb")
                                    .font(.system(size: 13))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            Text(suggested.explanation)
                                .font(.system(size: 12))
                                .foregroundStyle(HCDesign.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                HCAccentTag(title: suggested.confidence)
                                Spacer()
                                Text("\(completed.count) / \(ex.prescribedSets) SETS")
                                    .font(HCDesign.label(10))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                    }
                    HCSectionTitle(title: "Set controls", detail: "Tap + or –")
                    HCCard {
                        VStack(spacing: 16) {
                            Toggle(isOn: $hasWeight) {
                                Text("RECORD WEIGHT")
                                    .font(HCDesign.label(11))
                                    .tracking(1)
                            }
                            .tint(HCDesign.electric)
                            if hasWeight {
                                HCNumberControl(label: suggested.perDumbbell ? "LB / DUMBBELL" : "WEIGHT · LB",
                                                value: weight.formatted(),
                                                decrement: { weight = max(0, weight - 5) },
                                                increment: { weight = min(1500, weight + 5) })
                            }
                            if ex.isUnilateral {
                                HStack(spacing: 10) {
                                    ForEach([HCWorkingSide.left, HCWorkingSide.right],
                                            id: \.self) { side in
                                        let completedOnSide = completed.filter { $0.side == side }.count
                                        Button {
                                            workingSide = side
                                        } label: {
                                            HStack {
                                                Text(side == .left ? "LEFT" : "RIGHT")
                                                    .font(.system(size: 12, weight: .bold))
                                                Spacer()
                                                Text("\(completedOnSide)/\(ex.prescribedSets / 2)")
                                                    .font(.system(size: 11))
                                            }
                                            .padding(12)
                                            .foregroundStyle(workingSide == side ?
                                                HCDesign.canvas : HCDesign.ink)
                                            .background(workingSide == side ?
                                                HCDesign.electric : HCDesign.card,
                                                in: RoundedRectangle(cornerRadius: 11))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            HCNumberControl(label: "REPETITIONS", value: "\(reps)",
                                            decrement: { reps = max(1, reps - 1) },
                                            increment: { reps = min(60, reps + 1) })
                            HCNumberControl(label: "REPS IN RESERVE", value: "\(rir)",
                                            decrement: { rir = max(0, rir - 1) },
                                            increment: { rir = min(6, rir + 1) })
                        }
                    }
                    HCCard(accent: active ? HCDesign.electric : nil) {
                        VStack(alignment: .leading, spacing: 12) {
                            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                if active, let started = coach.phoneSetStartedAt {
                                    IMUNThemeTimerFace(
                                        seconds: timeline.date.timeIntervalSince(started),
                                        countsDown: false)
                                } else if let rest = coach.phoneRestEndsAt, rest > timeline.date {
                                    IMUNThemeTimerFace(
                                        seconds: rest.timeIntervalSince(timeline.date),
                                        countsDown: true)
                                }
                            }
                            if coach.phoneSessionStartedAt == nil {
                                HCFilledButton(title: "START WORKOUT TIMER", icon: "play.fill") {
                                    coach.startPhoneWorkout()
                                }
                            } else if active {
                                HCFilledButton(title: "STOP & SAVE SET", icon: "checkmark.circle.fill") {
                                    coach.logFromPhone(exercise: ex, weightLb: hasWeight ? weight : nil,
                                                       reps: reps, rir: Double(rir),
                                                       sideOverride: ex.isUnilateral ? workingSide : nil)
                                }
                                HCOutlineButton(title: "Cancel active set", icon: "xmark") {
                                    coach.cancelPhoneSet()
                                }
                            } else if coach.phoneSetStartedAt == nil {
                                HCFilledButton(title: "START SET \(completed.count + 1)", icon: "play.fill") {
                                    coach.startPhoneSet(exercise: ex)
                                }
                            } else {
                                Text("Another set is active. Finish it before starting this movement.")
                                    .font(.caption).foregroundStyle(HCDesign.secondary)
                            }
                            if coach.phoneRestEndsAt != nil {
                                HCOutlineButton(title: "Skip rest countdown", icon: "forward.fill") {
                                    coach.skipPhoneRest()
                                }
                            }
                            HCOutlineButton(title: "Log without timing", icon: "plus.circle") {
                                coach.logFromPhone(exercise: ex, weightLb: hasWeight ? weight : nil,
                                                   reps: reps, rir: Double(rir),
                                                   sideOverride: ex.isUnilateral ? workingSide : nil)
                            }
                            if let last = completed.max(by: { $0.completedAt < $1.completedAt }) {
                                HCOutlineButton(title: "Undo Set",
                                                icon: "arrow.uturn.backward") {
                                    coach.undoSet(last.id)
                                }
                            }
                        }
                    }
                    HCSectionTitle(title: "Set history", detail: "Recorded this session")
                    ForEach(completed) { set in
                        HCCard {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(HCDesign.electric)
                                Text("SET \(set.index)" +
                                     (set.side.map { " · \($0.title.uppercased())" } ?? ""))
                                    .font(HCDesign.label(12))
                                Spacer()
                                Text("\(set.weightLb?.formatted() ?? "—") lb × \(set.reps)")
                                    .font(HCDesign.metric(17))
                                Button {
                                    coach.undoSet(set.id)
                                } label: {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(HCDesign.secondary)
                                        .frame(width: 36, height: 40)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Undo Set \(set.index)")
                            }
                            if let insight = set.motionInsight {
                                IMUNSetMotionInsights(insight: insight)
                            }
                            if let load = set.weightLb, load > 0,
                               (1...12).contains(set.reps) {
                                HStack {
                                    Text("EST. ONE-REP MAX")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(HCDesign.secondary)
                                    Spacer()
                                    Text(String(format: "%.1f lb", set.reps == 1 ?
                                        load : load * (1 + Double(set.reps) / 30)))
                                        .font(HCDesign.metric(15))
                                        .foregroundStyle(HCDesign.aqua)
                                }
                                Text("Epley estimate from logged weight and reps, not a tested maximum.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                    }
                    HCFilledButton(title: "SMART SWAP · SIMILAR MOVEMENTS",
                                   icon: "arrow.triangle.2.circlepath") {
                        smartSwapOpen = true
                    }
                    if let swapError {
                        Text(swapError)
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.aqua)
                    }
                    NavigationLink {
                        StrengthExerciseDetails(exerciseID: exerciseID)
                    } label: {
                        HStack {
                            Label("Edit targets, swap exercise or correct sets", systemImage: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(HCDesign.aqua)
                        .padding(12)
                    }
                    if let instructions = ex.instructions ??
                        HCExerciseLibrary.all.first(where: {
                            HCProgramCatalog.normalized($0.name) == HCProgramCatalog.normalized(ex.name)
                        })?.instructions {
                        HCCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HCSectionTitle(title: "Movement cues")
                                Text(instructions)
                                    .font(.subheadline)
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $smartSwapOpen) {
            if let exercise = ex {
                ExerciseLibraryPicker(replacing: exercise) { selected in
                    guard let plan = coach.workout,
                          let index = plan.exercises.firstIndex(where: {
                              $0.id == exercise.id
                          }) else { return }
                    guard completed.isEmpty,
                          coach.phoneSetExerciseID != exercise.id else {
                        swapError = "Undo recorded or active sets before swapping this movement."
                        return
                    }
                    let rounds = exercise.isUnilateral ?
                        max(1, exercise.prescribedSets / 2) : exercise.prescribedSets
                    let slots = selected.isUnilateral ? rounds * 2 : rounds
                    let proto = HCExercise(id: exercise.id,
                        name: selected.name, originalName: selected.name,
                        exerciseIndex: exercise.exerciseIndex,
                        prescribedSets: slots,
                        repMin: exercise.repMin, repMax: exercise.repMax,
                        suggestedWeightLb: nil, restSeconds: exercise.restSeconds)
                    let load = coach.suggestion(for: proto,
                                    on: plan.date, aggressive: aggressive).weightLb
                    var updated = HCExercise(id: exercise.id,
                        name: selected.name, originalName: selected.name,
                        exerciseIndex: exercise.exerciseIndex,
                        prescribedSets: slots, repMin: exercise.repMin,
                        repMax: exercise.repMax,
                        suggestedWeightLb: load, restSeconds: exercise.restSeconds)
                    updated.instructions = selected.instructions
                    var exercises = plan.exercises
                    exercises[index] = updated
                    coach.saveEditedWorkout(HCWorkout(id: plan.id,
                        date: plan.date, sessionKey: plan.sessionKey,
                        title: plan.title, exercises: exercises, isPreview: false))
                }
            }
        }
        .onAppear {
            if let ex {
                reps = ex.repMin
                if ex.isUnilateral {
                    let used = Set(completed.map(\.index))
                    let next = (1...max(1, ex.prescribedSets)).first {
                        !used.contains($0)
                    } ?? 1
                    workingSide = ex.side(forSet: next) ?? .left
                }
                let target = ex.suggestedWeightLb ?? coach.workout.flatMap {
                    coach.suggestion(for: ex, on: $0.date, aggressive: aggressive).weightLb
                }
                if let target {
                    weight = target
                    hasWeight = true
                }
            }
        }
    }
}

// MARK: - Run

private struct PremiumRunPage: View {
    @Binding var headerCollapsed: Bool
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    private var date: Date { Date() }
    @State private var movingSession: HCPlannedSession?
    @State private var showingStructuredRun = false
    @State private var showingCreateRun = false

    private var actual: HCProgressRun? {
        coach.runHistory.first { $0.date == HCPlanBuilder.dateString(date) }
    }
    private var comparablePrevious: HCProgressRun? {
        guard let actual, let meters = actual.distanceMeters, meters > 1000 else { return nil }
        return coach.runHistory.first {
            $0.id != actual.id && $0.date < actual.date &&
            $0.distanceMeters.map { abs($0 - meters) / meters <= 0.15 } == true &&
            $0.durationSeconds.map { $0 > 0 } == true
        }
    }
    private var paceComparison: String? {
        guard let actual, let past = comparablePrevious,
              let currentDistance = actual.distanceMeters, currentDistance > 0,
              let previousDistance = past.distanceMeters, previousDistance > 0,
              let currentTime = actual.durationSeconds, currentTime > 0,
              let previousTime = past.durationSeconds, previousTime > 0 else { return nil }
        let currentPace = currentTime * 1609.344 / currentDistance
        let previousPace = previousTime * 1609.344 / previousDistance
        let change = Int(abs(currentPace - previousPace).rounded())
        return "\(change / 60):\(String(format: "%02d", change % 60)) " +
               (currentPace <= previousPace ? "faster" : "slower") +
               " per mile than \(past.date)'s comparable run"
    }

    var body: some View {
        ScrollView {
            IMUNTrainingScrollProbe()
            VStack(alignment: .leading, spacing: 19) {
                HCSectionTitle(title: "Running", detail: "Today's plan")
                IMUNTrainingMindsetCard()
                if !coach.signedIn { PremiumLogin() }
                HCCard(accent: HCDesign.aqua) {
                    VStack(alignment: .leading, spacing: 17) {
                        HCAccentTag(title: "TODAY'S RUN", color: HCDesign.aqua)
                        Text(coach.runPlan?.title ?? "Nothing scheduled")
                            .font(HCDesign.display(26))
                        Text(coach.runPlan?.notes.isEmpty == false ?
                             (coach.runPlan?.notes ?? "") :
                             "Check the calendar for a planned run or review previous sessions.")
                            .font(.subheadline)
                            .foregroundStyle(HCDesign.secondary)
                        HStack {
                            HCMetricBlock(label: "Distance target",
                                          value: coach.runPlan?.targetDistanceMiles.map {
                                              String(format: "%.1f", $0) + " mi"
                                          } ?? "—", tint: HCDesign.aqua)
                            HCMetricBlock(label: "Session",
                                          value: coach.runPlan?.isCompleted == true ? "DONE" : "READY")
                        }
                        HCFilledButton(title: "BUILD & SEND INTERVAL RUN", icon: "applewatch",
                                       tint: HCDesign.aqua, disabled: coach.runPlan == nil) {
                            showingStructuredRun = true
                        }
                        if coach.runPlan == nil {
                            HCFilledButton(title: "CREATE TODAY'S RUN", icon: "plus.circle",
                                           tint: HCDesign.aqua) {
                                showingCreateRun = true
                            }
                        }
                        if let steps = coach.runPlan?.structuredSteps, !steps.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PRESCRIBED INTERVALS")
                                    .font(HCDesign.label(11)).foregroundStyle(HCDesign.aqua)
                                ForEach(Array(steps.enumerated()), id: \.offset) { indexedStep in
                                    let step = indexedStep.element
                                    let goal = step.seconds.map { "\(Int($0 / 60)) min" }
                                        ?? step.distanceMeters.map {
                                            String(format: "%.2f mi", $0 / 1609.344)
                                        } ?? "Open"
                                    let bpm = step.minBPM.flatMap { minimum in
                                        step.maxBPM.map { maximum in
                                            " · \(minimum)–\(maximum) bpm"
                                        }
                                    } ?? ""
                                    Text("\(step.title) · \(goal)\(bpm)")
                                        .font(.caption).foregroundStyle(HCDesign.secondary)
                                }
                            }
                        }
                        if coach.runPlan?.isCompleted == false {
                            HCOutlineButton(title: "I COMPLETED THIS RUN", icon: "checkmark.circle") {
                                coach.setRunManuallyCompleted(true)
                            }
                            Text("Use this if the run is missing from Apple Health. No distance, pace or heart-rate data will be invented.")
                                .font(.caption2).foregroundStyle(HCDesign.secondary)
                        }
                        if let entry = coach.plannedSessions.first(where: {
                            $0.date == HCPlanBuilder.dateString(date) && $0.kind == "run"
                        }) {
                            HCOutlineButton(title: "Move this run", icon: "calendar.badge.clock") {
                                movingSession = entry
                            }
                        }
                    }
                }
                IMUNTredictWorkoutCard()
                if let actual {
                    if let distance = actual.distanceMeters,
                       let target = coach.runPlan?.targetDistanceMiles,
                       target > 0 {
                        HCCard(accent: HCDesign.aqua) {
                            HCMetricGauge(title: "Today's distance",
                                          value: String(format: "%.2f mi", distance / 1609.344),
                                          progress: distance / (target * 1609.344),
                                          detail: String(format: "%.1f-mile planned target", target),
                                          tint: HCDesign.aqua,
                                          symbol: "figure.run")
                        }
                    }
                    if let paceComparison {
                        HCStatusLine(text: paceComparison,
                                     symbol: "arrow.left.arrow.right",
                                     tint: HCDesign.aqua)
                    }
                    HCSectionTitle(title: "Completed run", detail: actual.source)
                    HCCard {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                HCMetricBlock(label: "Distance",
                                              value: actual.distanceMeters.map {
                                                  String(format: "%.2f", $0 / 1609.344) + " mi"
                                              } ?? "—")
                                HCMetricBlock(label: "Elapsed",
                                              value: actual.durationSeconds.map(hcDuration) ?? "—",
                                              tint: HCDesign.electric)
                            }
                            if let meters = actual.distanceMeters, let seconds = actual.durationSeconds,
                               meters > 0 {
                                let perMile = seconds * 1609.344 / meters
                                Text("AVG PACE · \(hcDuration(perMile)) /mi")
                                    .font(HCDesign.label(12))
                                    .foregroundStyle(HCDesign.aqua)
                            }
                            HStack(spacing: 12) {
                                HCMetricBlock(label: "Average HR",
                                              value: actual.averageBPM.map { "\(Int($0)) bpm" } ?? "—",
                                              tint: HCDesign.aqua)
                                HCMetricBlock(label: "Calories",
                                              value: actual.activeCalories.map { "\(Int($0)) kcal" } ?? "—")
                            }
                            NavigationLink {
                                PremiumRunDetails(run: actual)
                            } label: {
                                HStack {
                                    Text("VIEW ALL RECORDED RUN DATA")
                                        .font(HCDesign.label(11))
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .foregroundStyle(HCDesign.electric)
                                .padding(.vertical, 6)
                            }
                            if !actual.splits.isEmpty {
                                HCSectionTitle(title: "Measured laps")
                                ForEach(actual.splits) { split in
                                    HStack {
                                        Text("SPLIT \(split.index)")
                                            .font(HCDesign.label(11))
                                            .foregroundStyle(HCDesign.secondary)
                                        Spacer()
                                        Text(hcDuration(split.elapsedSeconds))
                                            .font(HCDesign.metric(17))
                                    }
                                    .padding(.vertical, 5)
                                }
                            }
                        }
                    }
                }
                HCSectionTitle(title: "Previous runs", detail: "Recorded only")
                ForEach(Array(coach.runHistory.prefix(15))) { run in
                    NavigationLink {
                        PremiumRunDetails(run: run)
                    } label: {
                        HCCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(run.date).font(HCDesign.label(11)).foregroundStyle(HCDesign.aqua)
                                    Text(run.title).font(.system(size: 15, weight: .bold))
                                    Text(run.source).font(.caption2).foregroundStyle(HCDesign.secondary)
                                }
                                Spacer()
                                Text(run.distanceMeters.map { String(format: "%.2f", $0 / 1609.344) } ?? "—")
                                    .font(HCDesign.metric(20))
                                Text("mi").font(.caption).foregroundStyle(HCDesign.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2).foregroundStyle(HCDesign.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if coach.runHistory.isEmpty {
                    HCCard {
                        Text("No completed runs yet.")
                            .font(.subheadline).foregroundStyle(HCDesign.secondary)
                    }
                }
                Spacer(minLength: 26)
            }
            .padding(.horizontal, 18)
        }
        .coordinateSpace(name: "imunTrainingScroll")
        .onPreferenceChange(IMUNTrainingScrollKey.self) { offset in
            // Hysteresis stops a collapsing header from bouncing repeatedly
            // at the exact scroll threshold while the page is dragged.
            if offset < -95 && !headerCollapsed {
                headerCollapsed = true
            } else if offset > -25 && headerCollapsed {
                headerCollapsed = false
            }
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $movingSession) { entry in
            IMUNMoveWorkoutSheet(entry: entry)
                .environmentObject(coach)
        }
        .sheet(isPresented: $showingStructuredRun) {
            if let plan = coach.runPlan {
                IMUNStructuredRunEditor(plan: plan)
            }
        }
        .sheet(isPresented: $showingCreateRun) {
            IMUNCreateRunSheet()
                .environmentObject(coach)
        }
    }
}


/// Prescribe a run without inventing workout measurements or modifying an
/// external Tredict/Garmin calendar. The new run also publishes to iMun Watch.
private struct IMUNCreateRunSheet: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Easy Run"
    @State private var minutes = 40
    @State private var targetHR = false
    @State private var minBPM = 120
    @State private var maxBPM = 150

    var body: some View {
        NavigationStack {
            Form {
                Section("Today's run") {
                    TextField("Workout title", text: $title)
                    HStack {
                        Text("Duration (minutes)")
                        Spacer()
                        TextField("Minutes", value: $minutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("Target heart-rate range", isOn: $targetHR)
                    if targetHR {
                        HStack {
                            TextField("Minimum BPM", value: $minBPM, format: .number)
                                .keyboardType(.numberPad)
                            Text("to")
                            TextField("Maximum BPM", value: $maxBPM, format: .number)
                                .keyboardType(.numberPad)
                        }
                    }
                }
                Section {
                    Button("Create run") {
                        if coach.createRunToday(
                            title: title, minutes: minutes,
                            minimumBPM: targetHR ? minBPM : nil,
                            maximumBPM: targetHR ? maxBPM : nil) {
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              !(1...360).contains(minutes) ||
                              (targetHR && (!(35...230).contains(minBPM) ||
                                            !(35...230).contains(maxBPM) ||
                                            minBPM > maxBPM)))
                    Text(coach.status).font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct PremiumRunDetails: View {
    let run: HCProgressRun

    private func number(_ v: Double?, unit: String = "", digits: Int = 0) -> String {
        guard let v else { return "Not shared" }
        return v.formatted(.number.precision(.fractionLength(digits))) + unit
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                PremiumHeader(eyebrow: "RUN / RECORDED", title: run.title,
                              subtitle: run.date + " · " + run.source,
                              badge: run.fromAppleHealth ? "APPLE HEALTH" : "CONNECTED")
                HCCard(accent: HCDesign.aqua) {
                    VStack(spacing: 17) {
                        HStack {
                            HCMetricBlock(label: "Distance", value: run.distanceMeters.map {
                                String(format: "%.2f mi", $0 / 1609.344)
                            } ?? "Not shared", tint: HCDesign.aqua)
                            HCMetricBlock(label: "Elapsed", value: run.durationSeconds.map(hcDuration) ?? "—")
                        }
                        HStack {
                            HCMetricBlock(label: "Average pace", value: {
                                guard let meters = run.distanceMeters, meters > 0,
                                      let seconds = run.durationSeconds else { return "—" }
                                return hcDuration(seconds * 1609.344 / meters) + "/mi"
                            }())
                            HCMetricBlock(label: "Active energy", value: number(run.activeCalories, unit: " kcal"))
                        }
                        HStack {
                            HCMetricBlock(label: "Average heart rate", value: number(run.averageBPM, unit: " bpm"))
                            HCMetricBlock(label: "Maximum heart rate", value: number(run.maxBPM, unit: " bpm"))
                        }
                        HStack {
                            HCMetricBlock(label: "Average run power", value: number(run.averagePowerWatts, unit: " W"))
                            HCMetricBlock(label: "Cadence", value: number(run.averageCadenceSPM, unit: " spm"))
                        }
                        HCMetricBlock(label: "Elevation gained", value: number(run.elevationGainMeters, unit: " m"))
                    }
                }
                if !run.heartRateTrace.isEmpty {
                    HCSectionTitle(title: "Heart rate over time", detail: run.source)
                    HCCard {
                        Chart(run.heartRateTrace) { item in
                            LineMark(x: .value("Time", item.at),
                                     y: .value("Heart rate", item.bpm))
                                .foregroundStyle(HCDesign.aqua)
                                .interpolationMethod(.linear)
                        }
                        .chartYAxisLabel("bpm")
                        .frame(height: 205)
                    }
                }
                if !run.routePoints.isEmpty {
                    HCSectionTitle(title: "Recorded GPS route", detail: run.source)
                    HCCard {
                        let points = run.routePoints.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        }
                        let latitudes = run.routePoints.map(\.latitude)
                        let longitudes = run.routePoints.map(\.longitude)
                        let latMin = latitudes.min() ?? 0
                        let latMax = latitudes.max() ?? 0
                        let lonMin = longitudes.min() ?? 0
                        let lonMax = longitudes.max() ?? 0
                        let center = CLLocationCoordinate2D(latitude: (latMin + latMax) / 2,
                                                             longitude: (lonMin + lonMax) / 2)
                        let span = MKCoordinateSpan(latitudeDelta: max(0.007, (latMax - latMin) * 1.5),
                                                    longitudeDelta: max(0.007, (lonMax - lonMin) * 1.5))
                        Map(initialPosition: .region(MKCoordinateRegion(center: center, span: span))) {
                            MapPolyline(coordinates: points)
                                .stroke(HCDesign.aqua, lineWidth: 4)
                        }
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("GPS locations remain stored on this iPhone.")
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Recorded lap events", detail: "\(run.splits.count)")
                if run.splits.isEmpty {
                    HCCard {
                        Text("This recorder did not share lap splits. Distance and total elapsed time may still be available.")
                            .font(.subheadline).foregroundStyle(HCDesign.secondary)
                    }
                } else {
                    ForEach(run.splits) { lap in
                        HCCard {
                            HStack {
                                Text("LAP \(lap.index)").font(HCDesign.label(12))
                                Spacer()
                                Text(hcDuration(lap.elapsedSeconds)).font(HCDesign.metric(19))
                                if let meters = lap.distanceMeters {
                                    Text(String(format: "%.2f mi", meters / 1609.344))
                                        .font(.caption).foregroundStyle(HCDesign.secondary)
                                }
                            }
                        }
                    }
                }
                HCCard {
                    VStack(alignment: .leading, spacing: 7) {
                        HCSectionTitle(title: "Provenance")
                        Text("Recorded by: \(run.source)")
                            .font(.system(size: 13, weight: .medium))
                        if let bundleID = run.sourceBundleID {
                            Text(bundleID).font(.caption2).foregroundStyle(HCDesign.secondary)
                        }
                        Text("Only data actually shared by the originating app appears here. Missing values and lap distances are not fabricated.")
                            .font(.caption).foregroundStyle(HCDesign.secondary)
                    }
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Analytics

private struct HCPlotMark: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// Date editing lives here, not on the daily workout dashboards.
private struct IMUNMoveWorkoutSheet: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Environment(\.dismiss) private var dismiss
    let entry: HCPlannedSession
    @State private var destination: Date

    init(entry: HCPlannedSession) {
        self.entry = entry
        _destination = State(initialValue: HCPlanBuilder.startOfDate(entry.date) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    Text(entry.title).font(.headline)
                    LabeledContent("Type", value: entry.kind == "lift-template" ?
                                   "Strength rotation" : entry.kind.capitalized)
                    LabeledContent("Current date", value: entry.date)
                }
                Section("Reschedule") {
                    DatePicker("Move to", selection: $destination,
                               displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(HCDesign.electric)
                    Text("Moving a workout updates your Command Center calendar. Previously recorded sets and completed runs stay on their original dates.")
                        .font(.caption)
                        .foregroundStyle(HCDesign.secondary)
                }
                Section {
                    Button {
                        coach.moveWorkout(entry, to: destination)
                        dismiss()
                    } label: {
                        Label("Save new workout day", systemImage: "checkmark")
                            .font(.headline)
                            .foregroundStyle(HCDesign.electric)
                    }
                    .disabled(coach.movingWorkoutID != nil ||
                              HCPlanBuilder.dateString(destination) == entry.date)
                }
            }
            .scrollContentBackground(.hidden)
            .background(HCDesign.canvas)
            .navigationTitle("Move workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct IMUNSetHistoryPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge

    var body: some View {
        List {
            Section {
                Text("Saved working sets from your earlier Health Coach sessions and IMUN Watch recordings. Loads are shown in pounds.")
                    .font(.caption)
                    .foregroundStyle(HCDesign.secondary)
            }
            ForEach(Array(coach.performanceHistory
                .sorted { $0.date == $1.date ? $0.exercise < $1.exercise : $0.date > $1.date }
                .prefix(350).enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.date)
                            .font(HCDesign.label(11))
                            .foregroundStyle(HCDesign.electric)
                        Spacer()
                        Text(row.source)
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                    Text(row.exercise)
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(row.weightLb.formatted()) lb × \(row.reps) reps" +
                         (row.rir.map { "  ·  RIR \($0.formatted())" } ?? ""))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HCDesign.secondary)
                }
                .listRowBackground(HCDesign.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(HCDesign.canvas)
        .navigationTitle("Strength history")
    }
}

/// A historical workout identified by its original date/session key. Actual
/// motion data is resolved from the live workout archive when the screen opens.
private struct IMUNMotionSession: Identifiable {
    let date: String
    let sessionKey: String
    let title: String
    var id: String { date + "|" + sessionKey }

    static func all(_ sets: [HCLoggedSet]) -> [IMUNMotionSession] {
        let groups = Dictionary(grouping: sets, by: {
            $0.workoutDate + "|" + $0.sessionKey
        })
        return groups.compactMap { _, entries -> IMUNMotionSession? in
            guard let mostRecent = entries.max(by: {
                $0.completedAt < $1.completedAt
            }) else { return nil }
            return .init(date: mostRecent.workoutDate,
                         sessionKey: mostRecent.sessionKey,
                         title: mostRecent.workoutTitle)
        }.sorted { $0.date == $1.date ?
            $0.title < $1.title : $0.date > $1.date }
    }
}

private struct IMUNMotionExerciseTrendView: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    let exerciseName: String
    let placement: String

    private var history: [HCLoggedSet] {
        IMUNMotionAnalytics.comparableSets(coach.motionHistorySets,
            exerciseName: exerciseName, location: placement)
    }
    private var motion: IMUNMotionForecast? {
        IMUNMotionAnalytics.forecastMotion(coach.motionHistorySets,
            exerciseName: exerciseName, location: placement)
    }
    private var strength: IMUNStrengthForecast? {
        IMUNMotionAnalytics.forecastStrength(coach.motionHistorySets,
            exerciseName: exerciseName)
    }

    var body: some View {
        HCCard {
            VStack(alignment: .leading, spacing: 11) {
                Text(exerciseName.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(HCDesign.ink)
                Text("SOURCE-MATCHED PROGRESS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(HCDesign.aqua)
                if history.count >= 2 {
                    Chart(history, id: \.id) { entry in
                        if let seconds = entry.motionInsight?.averageCycleSeconds {
                            LineMark(x: .value("Session", entry.completedAt),
                                     y: .value("Cycle duration", seconds))
                                .foregroundStyle(HCDesign.aqua)
                            PointMark(x: .value("Session", entry.completedAt),
                                      y: .value("Cycle duration", seconds))
                                .foregroundStyle(HCDesign.electric)
                        }
                    }
                    .frame(height: 140)
                    Text("Detected cycle duration across recorded sets. Comparing matching exercise and placement only.")
                        .font(.system(size: 10))
                        .foregroundStyle(HCDesign.secondary)
                }
                if let prediction = motion {
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(format: "%.2f s", prediction.projectedNextCycleSeconds))
                            .font(HCDesign.metric(24))
                            .foregroundStyle(HCDesign.electric)
                        Text("next-session cycle-time projection")
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    Text("\(prediction.sessionCount) comparable sessions · \(prediction.confidence) confidence")
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.aqua)
                    Text(prediction.explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                } else {
                    Text("Motion projections need at least four comparable sessions with adequate capture quality and the same sensor position.")
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                }
                if let strength {
                    HStack(spacing: 8) {
                        Text(String(format: "Est. 1RM: %.1f lb", strength.lastEstimatedMaxLb))
                        Spacer(minLength: 4)
                        Text(String(format: "Next trend: %.1f lb", strength.projectedNextEstimatedMaxLb))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(HCDesign.ink)
                    Text("Arithmetic projection from \(strength.sessionCount) workouts (\(strength.confidence.lowercased()) confidence), not a prescribed lift or measured maximum.")
                        .font(.system(size: 10))
                        .foregroundStyle(HCDesign.secondary)
                }
            }
        }
    }
}


/// Local session analysis from compact Apple Watch motion summaries. We retain
/// the per-set quality and movement proxies without fabricating biomechanics.
private enum IMUNMotionSessionReview {
    static func observations(_ sets: [HCLoggedSet]) -> [String] {
        let tracked = sets.compactMap(\.motionInsight)
        guard !tracked.isEmpty else {
            return ["No wrist-motion summaries for this session. Logged reps and weight remain available, but movement quality cannot be inferred."]
        }
        var result: [String] = []
        let confidence = tracked.filter { $0.analysisConfidence == "Moderate" }.count
        result.append("\(tracked.count) recorded sets have movement evidence; \(confidence) have moderate capture confidence. These are sensor-quality labels, not movement-quality grades.")
        let coverage = tracked.compactMap(\.sampleCoveragePercent)
            .filter(\.isFinite)
        if !coverage.isEmpty {
            let mean = coverage.reduce(0, +) / Double(coverage.count)
            result.append(String(format: "Average wrist-signal sample coverage was %.0f%% across %d sets.", mean, coverage.count))
        }
        let slowdown = tracked.compactMap(\.lastCycleSlowdownPercent)
            .filter { $0.isFinite && $0 > 18 }
        if !slowdown.isEmpty {
            result.append("\(slowdown.count) sets ended with a detected cycle over 18% slower than their earlier cycles. Check exercise, tempo intention and effort before treating this as fatigue.")
        }
        let travel = tracked.compactMap(\.lastWristRotationChangePercent)
            .filter { $0.isFinite && $0 < -18 }
        if !travel.isEmpty {
            result.append("\(travel.count) sets showed reduced final-cycle relative wrist rotation. This is not joint range of motion.")
        }
        let gaps = tracked.reduce(0) { $0 + ($1.samplingGapCount ?? 0) }
        if gaps > 0 {
            result.append("\(gaps) sensor interruptions may limit rep timing or comparison reliability.")
        }
        let corrections = sets.filter {
            guard let estimate = $0.motionInsight?.detectedReps else { return false }
            return estimate != $0.reps
        }.count
        if corrections > 0 {
            result.append("\(corrections) sets differ between saved reps and detected cycles. Manual corrections remain authoritative.")
        }
        return result
    }

    static func coachContext(title: String, sets: [HCLoggedSet]) -> String {
        var lines = [
            "The athlete opened a workout-specific IsAIah movement review for " + title + ".",
            "Evidence is from experimental Apple Watch wrist accelerometer/gyroscope proxies; not bar speed, force, anatomical joint ROM or verified lifting form.",
            "Only analyze captured sets and comparable placement. Never diagnose injury or issue automatic workout edits.",
            "SESSION FINDINGS: " + observations(sets).joined(separator: " ")
        ]
        for item in sets.prefix(28) {
            let prefix = "\(item.exerciseName) / set \(item.index) / saved reps \(item.reps)"
            guard let data = item.motionInsight else {
                lines.append(prefix + " / no motion capture")
                continue
            }
            var facts = [
                prefix,
                "detected cycles \(data.detectedReps)",
                "sensor \(data.source)",
                "position \(data.wearableLocation ?? data.wearSide)",
                "capture confidence \(data.analysisConfidence ?? "unrated")"
            ]
            if let coverage = data.sampleCoveragePercent {
                facts.append(String(format: "coverage %.0f%%", coverage))
            }
            if let tempo = data.averageCycleSeconds {
                facts.append(String(format: "average cycle %.2f sec", tempo))
            }
            if let last = data.lastCycleSlowdownPercent {
                facts.append(String(format: "last-cycle slowdown %+.0f%%", last))
            }
            if let rotation = data.meanWristRotationDegrees {
                facts.append(String(format: "mean integrated wrist rotation %.0f degrees (proxy)", rotation))
            }
            if let peak = data.peakWristRotationDegreesPerSecond {
                facts.append(String(format: "peak wrist rotation %.0f degrees/sec", peak))
            }
            if let warnings = data.analysisWarnings, !warnings.isEmpty {
                facts.append("warnings " + warnings.joined(separator: "; "))
            }
            lines.append(facts.joined(separator: " | "))
        }
        return lines.joined(separator: "\n")
    }
}

private struct IMUNMotionWorkoutDetail: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    let session: IMUNMotionSession

    private var sets: [HCLoggedSet] {
        coach.motionHistorySets.filter {
            $0.workoutDate == session.date &&
            $0.sessionKey == session.sessionKey
        }.sorted { a, b in
            a.exerciseIndex == b.exerciseIndex ?
                a.index < b.index : a.exerciseIndex < b.exerciseIndex
        }
    }
    private var exerciseNames: [String] {
        Array(Set(sets.map(\.exerciseName))).sorted()
    }
    private var matchedMeasuredActivity: HCTrainingActivity? {
        coach.trainingActivities.first {
            $0.date == session.date &&
            HCProgramCatalog.normalized($0.title) ==
                HCProgramCatalog.normalized(session.title)
        }
    }
    private var recordedReps: Int { sets.reduce(0) { $0 + $1.reps } }
    private var detectedCycles: Int {
        sets.reduce(0) { $0 + ($1.motionInsight?.detectedReps ?? 0) }
    }
    private var volume: Double {
        sets.reduce(0) { $0 + ($1.weightLb ?? 0) * Double($1.reps) }
    }
    private var liftingSeconds: Double {
        sets.reduce(0) { $0 + max(0, $1.durationSeconds ?? 0) }
    }
    private var restSeconds: Double {
        let chronological = sets.sorted { $0.completedAt < $1.completedAt }
        guard chronological.count >= 2 else { return 0 }
        return zip(chronological.dropLast(), chronological.dropFirst())
            .reduce(0) { sum, pair in
                guard let nextStart = pair.1.startedAt,
                      nextStart > pair.0.completedAt else { return sum }
                return sum + min(7200, nextStart.timeIntervalSince(pair.0.completedAt))
            }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 15) {
                PremiumHeader(eyebrow: "PROGRESS / MOTION ANALYSIS",
                              title: session.title,
                              subtitle: session.date + " · Experimental Apple Watch movement")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 9) {
                    HCCard { HCMetricBlock(label: "Logged sets", value: "\(sets.count)") }
                    HCCard { HCMetricBlock(label: "Saved / detected",
                        value: "\(recordedReps) / \(detectedCycles)") }
                    HCCard { HCMetricBlock(label: "Training volume",
                        value: String(format: "%.0f lb", volume)) }
                    HCCard { HCMetricBlock(label: "Active set time",
                        value: hcDuration(liftingSeconds)) }
                    HCCard { HCMetricBlock(label: "Rest between sets",
                        value: hcDuration(restSeconds)) }
                }
                Text("Recorded reps may have been manually corrected. Detected cycles are sensor estimates; the counts need not match.")
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
                if let measured = matchedMeasuredActivity {
                    HCCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WORKOUT PHYSIOLOGY · " + measured.source.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(HCDesign.aqua)
                            HStack(spacing: 12) {
                                if let bpm = measured.averageBPM {
                                    HCMetricBlock(label: "Measured avg HR",
                                                  value: "\(Int(bpm)) bpm")
                                }
                                if let max = measured.maxBPM {
                                    HCMetricBlock(label: "Measured peak HR",
                                                  value: "\(Int(max)) bpm")
                                }
                                if let calories = measured.calories {
                                    HCMetricBlock(label: "Source-reported energy",
                                                  value: "\(Int(calories)) kcal")
                                }
                            }
                            Text("Only original measurements from this matched workout are shown; missing signals are not estimated.")
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                HCSectionTitle(title: "Session interpretation",
                               detail: "Evidence from captured Apple Watch sets")
                HCCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(IMUNMotionSessionReview.observations(sets).enumerated()),
                                id: .offset) { entry in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "waveform.path")
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.aqua)
                                    .frame(width: 16)
                                Text(entry.element)
                                    .font(.system(size: 12))
                                    .foregroundStyle(HCDesign.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        NavigationLink {
                            PremiumCoachConversation(
                                launchContext: IMUNMotionSessionReview.coachContext(
                                    title: session.title, sets: sets))
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "sparkle.magnifyingglass")
                                Text("Analyze this workout with IsAIah")
                                Spacer(minLength: 4)
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HCDesign.electric)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Text("Opening IsAIah prepares a summary; it is sent only when you submit a message.")
                            .font(.system(size: 10))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Exercises and rep analysis",
                               detail: "Measured wrist signals, not joint angles")
                ForEach(exerciseNames, id: \.self) { name in
                    let grouped = sets.filter { $0.exerciseName == name }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(name.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(HCDesign.ink)
                        ForEach(grouped) { set in
                            HCCard {
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack {
                                        Text("SET \(set.index)" +
                                             (set.side.map { " · \($0.title.uppercased())" } ?? ""))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(HCDesign.electric)
                                        Spacer()
                                        Text("\(set.reps) saved reps")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    Text("\(set.weightLb.map { String(format: "%.1f lb", $0) } ?? "No load logged") · \(set.durationSeconds.map(hcDuration) ?? "duration unavailable")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(HCDesign.secondary)
                                    if let insight = set.motionInsight {
                                        IMUNSetMotionInsights(insight: insight)
                                    }
                                }
                            }
                        }
                    }
                }
                HCSectionTitle(title: "IsAIah trend projections",
                               detail: "Comparable exercise and sensor positions only")
                ForEach(exerciseNames, id: \.self) { name in
                    let relevant = sets.filter { $0.exerciseName == name }
                    let locations = Set(relevant.compactMap { entry in
                        entry.motionInsight.map(IMUNMotionAnalytics.placement)
                    })
                    ForEach(Array(locations).sorted(), id: \.self) { location in
                        IMUNMotionExerciseTrendView(exerciseName: name,
                                                     placement: location)
                    }
                }
                Text("Not available from this sensor: verified squat depth, joint range, actual dumbbell speed, force, physical power in watts, and automated form diagnosis. These require additional validated measurements.")
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
                Spacer(minLength: 20)
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationTitle("Motion Analysis")
    }
}

private struct IMUNMotionHistoryPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    private var sessions: [IMUNMotionSession] {
        IMUNMotionSession.all(coach.motionHistorySets)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 13) {
                PremiumHeader(eyebrow: "PROGRESS / PERFORMANCE LAB",
                              title: "Movement intelligence",
                              subtitle: "Your saved rep data, session by session")
                HCCard {
                    Text(coach.motionHistoryStatus)
                        .font(.system(size: 12))
                        .foregroundStyle(HCDesign.secondary)
                    HCOutlineButton(title: "Refresh motion history",
                                    icon: "arrow.clockwise") {
                        coach.refreshMotionHistory(force: true)
                    }
                }
                if sessions.isEmpty {
                    HCCard {
                        Text("No saved motion sets yet. Complete a tracked Apple Watch lifting set to begin collecting your movement baseline.")
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                ForEach(sessions) { session in
                    NavigationLink {
                        IMUNMotionWorkoutDetail(session: session)
                    } label: {
                        HCCard {
                            HStack(spacing: 13) {
                                Image(systemName: "waveform.path.ecg.rectangle")
                                    .font(.system(size: 21))
                                    .foregroundStyle(HCDesign.aqua)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(session.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(HCDesign.ink)
                                    Text(session.date)
                                        .font(.system(size: 11))
                                        .foregroundStyle(HCDesign.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(HCDesign.electric)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationTitle("Motion History")
        .onAppear { coach.refreshMotionHistory() }
    }
}

private struct IMUNActivityDetails: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    let activity: HCTrainingActivity

    private var matchedMotionSession: IMUNMotionSession? {
        IMUNMotionSession.all(coach.motionHistorySets).first {
            $0.date == activity.date &&
            HCProgramCatalog.normalized($0.title) ==
                HCProgramCatalog.normalized(activity.title)
        }
    }

    private var measurements: [(String, String)] {
        var rows: [(String, String)] = []
        if let seconds = activity.durationSeconds { rows.append(("Moving time", hcDuration(seconds))) }
        if let seconds = activity.totalDurationSeconds { rows.append(("Total elapsed", hcDuration(seconds))) }
        if let meters = activity.distanceMeters { rows.append(("Distance", String(format: "%.2f miles", meters / 1609.344))) }
        if let seconds = activity.paceSecondsPerKm { rows.append(("Pace", hcDuration(seconds * 1.609344) + " /mi")) }
        if let avg = activity.averageBPM { rows.append(("Average heart rate", "\(Int(avg)) bpm")) }
        if let max = activity.maxBPM { rows.append(("Maximum heart rate", "\(Int(max)) bpm")) }
        if let kcal = activity.calories { rows.append(("Calories", "\(Int(kcal)) kcal")) }
        if let watts = activity.powerWatts { rows.append(("Average power", "\(Int(watts)) W")) }
        if let cadence = activity.cadenceSPM { rows.append(("Cadence", "\(Int(cadence)) spm")) }
        if let ascent = activity.ascentMeters { rows.append(("Elevation gained", "\(Int(ascent)) m")) }
        if let sets = activity.strengthSetCount { rows.append(("Recorded strength sets", "\(sets)")) }
        if let reps = activity.strengthRepetitions { rows.append(("Total repetitions", "\(reps)")) }
        if let volume = activity.tonnageKilograms {
            rows.append(("Tonnage", String(format: "%.1f kg", volume)))
        }
        if let load = activity.maxSetWeightKilograms {
            rows.append(("Highest set load", String(format: "%.1f kg", load)))
        }
        if let seconds = activity.activeSetSeconds { rows.append(("Time lifting", hcDuration(seconds))) }
        if let seconds = activity.restSeconds { rows.append(("Time resting", hcDuration(seconds))) }
        if let score = activity.runningEffectiveness {
            rows.append(("Running effectiveness", score.formatted(.number.precision(.fractionLength(2)))))
        }
        if let vo2 = activity.vo2Max {
            rows.append(("Estimated VO₂max", vo2.formatted(.number.precision(.fractionLength(1)))))
        }
        if let effort = activity.perceivedEffort {
            rows.append(("Recorded RPE", effort.formatted(.number.precision(.fractionLength(1)))))
        }
        if let enjoyment = activity.enjoyment {
            rows.append(("Recorded enjoyment", enjoyment.formatted(.number.precision(.fractionLength(1)))))
        }
        return rows
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                PremiumHeader(eyebrow: "IMUN / TRAINING HISTORY",
                              title: activity.title,
                              subtitle: activity.date + " · " + activity.source)
                HCCard {
                    VStack(alignment: .leading, spacing: 13) {
                        ForEach(measurements.indices, id: \.self) { i in
                            HStack(alignment: .firstTextBaseline) {
                                Text(measurements[i].0)
                                    .font(.system(size: 13))
                                    .foregroundStyle(HCDesign.secondary)
                                Spacer(minLength: 7)
                                Text(measurements[i].1)
                                    .font(.system(size: 13, weight: .semibold))
                                    .multilineTextAlignment(.trailing)
                            }
                            if i != measurements.count - 1 { Divider().overlay(HCDesign.outline) }
                        }
                        if measurements.isEmpty {
                            Text("The original service recorded a workout, but did not provide numeric measurements.")
                                .font(.subheadline).foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                if let session = matchedMotionSession {
                    NavigationLink {
                        IMUNMotionWorkoutDetail(session: session)
                    } label: {
                        HCCard {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                    .foregroundStyle(HCDesign.aqua)
                                Text("View this workout's motion analysis")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                HCCard {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ORIGINAL RECORD").font(HCDesign.label(11)).foregroundStyle(HCDesign.electric)
                        Text("Source: " + activity.source)
                            .font(.system(size: 13))
                        if let name = activity.attribution {
                            Text("Device: " + name).font(.system(size: 12)).foregroundStyle(HCDesign.secondary)
                        }
                        Text("All available values retain their original recorded units. Additional raw Tredict fields remain in your local source archive.")
                            .font(.caption).foregroundStyle(HCDesign.secondary)
                    }
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PremiumProgressPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @AppStorage("hcDesignPreset") private var progressPreset = "techno"
    @State private var selectedExercise = ""
    @State private var rangeDays = 30
    @State private var movingSession: HCPlannedSession?
    @State private var showAllUpcomingSessions = false
    // Chart points are rebuilt only when source histories/selection change,
    // never repeatedly while a user scrolls through the training cards.
    @State private var cachedExerciseNames: [String] = []
    @State private var cachedStrengthPoints: [HCPlotMark] = []
    @State private var cachedRunPoints: [HCPlotMark] = []

    private var upcoming: [HCPlannedSession] {
        let today = HCPlanBuilder.dateString(Date())
        return Array(coach.plannedSessions.filter { $0.date >= today }.prefix(45))
    }

    private var names: [String] { cachedExerciseNames }
    private var cutoff: Date {
        Calendar.current.date(byAdding: .day, value: -rangeDays, to: Date()) ?? .distantPast
    }
    private var strengthPoints: [HCPlotMark] {
        cachedStrengthPoints.filter { $0.date >= cutoff }
    }
    private var runPoints: [HCPlotMark] {
        cachedRunPoints.filter { $0.date >= cutoff }
    }
    private var monthlyVolumeLb: Double {
        coach.performanceHistory.reduce(0) { sum, row in
            guard let date = HCPlanBuilder.startOfDate(row.date), date >= cutoff else { return sum }
            return sum + row.weightLb * Double(row.reps)
        }
    }
    private var activeDates: Set<String> {
        Set(coach.trainingActivities.compactMap { row in
            guard let date = HCPlanBuilder.startOfDate(row.date), date >= cutoff else { return nil }
            return row.date
        })
    }
    private var currentStreak: Int {
        let days = Set(coach.trainingActivities.map(\.date))
        let calendar = Calendar.current
        let start = days.contains(HCPlanBuilder.dateString(Date())) ?
            Date() : (calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        var count = 0
        for offset in 0..<180 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start),
                  days.contains(HCPlanBuilder.dateString(day)) else { break }
            count += 1
        }
        return count
    }
    private var runMiles: Double {
        coach.runHistory.reduce(0) { total, row in
            guard let date = HCPlanBuilder.startOfDate(row.date), date >= cutoff else { return total }
            return total + (row.distanceMeters ?? 0) / 1609.344
        }
    }

    private func rebuildStrengthChart() {
        let available = Array(Set(coach.performanceHistory.map(\.exercise))).sorted()
        cachedExerciseNames = available
        let selected = selectedExercise.isEmpty ? (available.first ?? "") : selectedExercise
        cachedStrengthPoints = coach.performanceHistory.filter { $0.exercise == selected }
            .compactMap { row in
                HCPlanBuilder.startOfDate(row.date).map {
                    HCPlotMark(date: $0, value: row.weightLb)
                }
            }.sorted { $0.date < $1.date }
    }

    private func rebuildRunChart() {
        cachedRunPoints = coach.runHistory.compactMap { row in
            guard let distance = row.distanceMeters,
                  let date = HCPlanBuilder.startOfDate(row.date) else { return nil }
            return HCPlotMark(date: date, value: distance / 1609.344)
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            // A long training history should not create dozens of heavy cards
            // and chart surfaces before the first visible scroll frame.
            LazyVStack(alignment: .leading, spacing: 19) {
                HCPremiumHero(eyebrow: "PERFORMANCE / THE LONG GAME",
                              title: "Every session counts.",
                              subtitle: "Your history, your momentum, and the next milestone.",
                              icon: "chart.line.uptrend.xyaxis",
                              tint: HCDesign.aqua) {
                    HStack(spacing: 18) {
                        HCMetricBlock(label: "Recorded sets",
                                      value: "\(coach.performanceHistory.count)",
                                      tint: HCDesign.ink)
                        HCMetricBlock(label: "Recorded runs",
                                      value: "\(coach.runHistory.count)",
                                      tint: HCDesign.aqua)
                        HCMetricBlock(label: "Upcoming",
                                      value: "\(upcoming.count)",
                                      tint: HCDesign.ink)
                    }
                }
                HStack {
                    Text("ANALYSIS WINDOW")
                        .font(HCDesign.label(10))
                        .foregroundStyle(HCDesign.secondary)
                    Spacer()
                    Picker("Range", selection: $rangeDays) {
                        Text("7D").tag(7)
                        Text("30D").tag(30)
                        Text("90D").tag(90)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    HCCard { HCMetricBlock(label: "Strength volume", value:
                        String(format: "%.0f lb", monthlyVolumeLb)) }
                    HCCard { HCMetricBlock(label: "Running distance", value:
                        String(format: "%.1f mi", runMiles)) }
                    HCCard { HCMetricBlock(label: "Active days", value:
                        "\(activeDates.count) / \(rangeDays)") }
                    HCCard { HCMetricBlock(label: "Current streak", value:
                        "\(currentStreak) days") }
                }
                HCSectionTitle(title: "Exercise progression", detail: "Recorded weight")
                HCCard {
                    VStack(alignment: .leading, spacing: 16) {
                        if names.isEmpty {
                            if coach.loading {
                                IMUNLoadingPlaceholder(lines: 3, height: 140)
                            } else {
                                Text("No logged strength history yet.")
                                    .font(.subheadline).foregroundStyle(HCDesign.secondary)
                            }
                        } else {
                            Picker("Exercise", selection: $selectedExercise) {
                                Text("Select movement").tag("")
                                ForEach(names, id: \.self) { Text($0).tag($0) }
                            }
                            .tint(HCDesign.aqua)
                            NavigationLink {
                                IMUNExerciseAnalytics(exercise: selectedExercise.isEmpty ?
                                    (names.first ?? "") : selectedExercise)
                            } label: {
                                Label("Explore exercise history & personal records",
                                      systemImage: "arrow.up.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .tint(HCDesign.electric)
                            if !strengthPoints.isEmpty {
                                Chart(strengthPoints) { point in
                                    LineMark(x: .value("Date", point.date),
                                             y: .value("Weight", point.value))
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(HCDesign.electric)
                                    PointMark(x: .value("Date", point.date),
                                              y: .value("Weight", point.value))
                                        .foregroundStyle(HCDesign.electric)
                                }
                                .chartYAxisLabel("lb")
                                .frame(height: 205)
                            }
                        }
                        Text("Equipment-specific loads are kept separate. Dumbbell weights are per implement.")
                            .font(.caption2).foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Running volume")
                HCCard {
                    if runPoints.isEmpty {
                        if coach.loading {
                            IMUNLoadingPlaceholder(lines: 3, height: 110)
                        } else {
                            Text("No measured running distances yet.")
                                .foregroundStyle(HCDesign.secondary)
                        }
                    } else {
                        Chart(runPoints) { p in
                            BarMark(x: .value("Date", p.date, unit: .day),
                                    y: .value("Miles", p.value))
                                .foregroundStyle(HCDesign.aqua.gradient)
                                .cornerRadius(4)
                        }
                        .frame(height: 210)
                    }
                }
                HCCard(accent: HCDesign.electric) {
                    VStack(alignment: .leading, spacing: 8) {
                        IMUNThemeProgressView(
                            completed: coach.workout.map {
                                coach.completedSets(for: $0).count
                            } ?? 0,
                            planned: coach.workout?.prescribedSetCount ?? 0)
                        Text("TODAY'S PRESCRIBED WORKING SETS · RECORDED ON BOTH DEVICES")
                            .font(HCDesign.label(9))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                HCCard {
                    HCMetricBlock(label: "Total logged run distance",
                                  value: String(format: "%.1f mi",
                                    coach.runHistory.compactMap(\.distanceMeters).reduce(0,+) / 1609.344),
                                  tint: HCDesign.electric)
                }
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Upcoming workouts")
                            .font(.system(size: 18, weight: .semibold,
                                          design: progressPreset == "heritage" ||
                                                  progressPreset == "atelier" ?
                                                  .serif : .default))
                            .foregroundStyle(HCDesign.ink)
                        Text("Tap to reschedule")
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    Spacer(minLength: 8)
                    if upcoming.count > 3 {
                        Button(showAllUpcomingSessions ? "Show less" : "See all \(upcoming.count)") {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showAllUpcomingSessions.toggle()
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HCDesign.electric)
                        .buttonStyle(.plain)
                        .accessibilityLabel(showAllUpcomingSessions ?
                            "Show next three workouts" : "See all upcoming workouts")
                    }
                }
                if upcoming.isEmpty {
                    HCCard {
                        Text("No upcoming sessions in your connected calendar. Add workouts through Command Center.")
                            .font(.subheadline).foregroundStyle(HCDesign.secondary)
                    }
                } else {
                    ForEach(showAllUpcomingSessions ? upcoming : Array(upcoming.prefix(3))) { entry in
                        HCCard {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    Text(entry.date)
                                        .font(HCDesign.label(11))
                                        .foregroundStyle(HCDesign.electric)
                                    Spacer()
                                    Text(entry.kind == "lift-template" ? "STRENGTH · ROTATION" : entry.kind.uppercased())
                                        .font(HCDesign.label(10))
                                        .foregroundStyle(HCDesign.secondary)
                                }
                                Text(entry.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(HCDesign.ink)
                                if !entry.notes.isEmpty {
                                    Text(entry.notes)
                                        .font(.caption)
                                        .foregroundStyle(HCDesign.secondary)
                                        .lineLimit(2)
                                }
                                HStack(spacing: 12) {
                                    Button {
                                        movingSession = entry
                                    } label: {
                                        Label("Move day", systemImage: "calendar")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .disabled(coach.movingWorkoutID != nil)
                                    if entry.date != HCPlanBuilder.dateString(Date()) {
                                        Button {
                                            coach.moveWorkout(entry, to: Date())
                                        } label: {
                                            Label("Today", systemImage: "arrow.uturn.backward")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .disabled(coach.movingWorkoutID != nil)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(HCDesign.electric)
                            }
                        }
                    }
                }
                if coach.movingWorkoutID != nil {
                    ProgressView("Saving your schedule…").tint(HCDesign.electric)
                }
                HCSectionTitle(title: "Completed training", detail: "Health Coach + Tredict")
                if coach.trainingActivities.isEmpty {
                    Text("No completed training sessions yet.")
                        .foregroundStyle(HCDesign.secondary)
                } else {
                    ForEach(coach.trainingActivities.prefix(35)) { activity in
                        NavigationLink {
                            IMUNActivityDetails(activity: activity)
                        } label: {
                            HCCard {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(activity.date).foregroundStyle(HCDesign.electric)
                                    Spacer()
                                    Text(activity.source).foregroundStyle(HCDesign.secondary)
                                }
                                .font(HCDesign.label(10))
                                Text(activity.title).font(.system(size: 15, weight: .semibold))
                                HStack(spacing: 12) {
                                    if let seconds = activity.durationSeconds {
                                        Label(hcDuration(seconds), systemImage: "clock")
                                    }
                                    if let meters = activity.distanceMeters, meters > 0 {
                                        Label(String(format: "%.2f mi", meters / 1609.344),
                                              systemImage: "figure.run")
                                    }
                                    if let hr = activity.averageBPM {
                                        Label("\(Int(hr)) bpm", systemImage: "heart")
                                    }
                                    if let kcal = activity.calories {
                                        Label("\(Int(kcal)) kcal", systemImage: "flame")
                                    }
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(HCDesign.secondary)
                                .lineLimit(1)
                            }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                HCSectionTitle(title: "Motion intelligence",
                               detail: "Recorded Apple Watch sensor observations")
                NavigationLink {
                    IMUNMotionHistoryPage()
                } label: {
                    HCCard {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform.path.ecg.rectangle")
                                .font(.system(size: 21))
                                .foregroundStyle(HCDesign.aqua)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Explore completed workout motion")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(HCDesign.ink)
                                Text("\(coach.motionHistorySets.count) saved motion sets · tempo, rotation, consistency and trends")
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            Spacer(minLength: 2)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(HCDesign.electric)
                        }
                    }
                }
                .buttonStyle(.plain)
                HCSectionTitle(title: "Past working sets", detail: "\(coach.performanceHistory.count) records")
                NavigationLink {
                    IMUNSetHistoryPage()
                } label: {
                    HCCard {
                        HStack {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .foregroundStyle(HCDesign.electric)
                            Text("View every logged weight, rep and RIR")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer(minLength: 30)
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Progress")
        .sheet(item: $movingSession) { entry in
            IMUNMoveWorkoutSheet(entry: entry)
                .environmentObject(coach)
        }
        .onAppear {
            rebuildStrengthChart()
            rebuildRunChart()
            coach.refreshMotionHistory()
        }
        .onChange(of: selectedExercise) { _, _ in rebuildStrengthChart() }
        .onReceive(coach.$performanceHistory) { _ in
            // @Published emits immediately before storage changes; use the next
            // main-queue turn so the snapshot sees the published history.
            DispatchQueue.main.async { rebuildStrengthChart() }
        }
        .onReceive(coach.$runHistory) { _ in
            DispatchQueue.main.async { rebuildRunChart() }
        }
    }
}

/// A detailed, exercise-specific record, always computed from actual logged
/// weights/reps rather than an inferred training max.
private struct IMUNExerciseAnalytics: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    let exercise: String
    @State private var rangeDays = 90

    private var entries: [HCPerformanceSet] {
        coach.performanceHistory.filter { $0.exercise == exercise }
            .sorted { $0.date > $1.date }
    }
    private var marks: [HCPlotMark] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -rangeDays,
                                           to: Date()) ?? .distantPast
        return entries.compactMap { row in
            guard let date = HCPlanBuilder.startOfDate(row.date),
                  date >= cutoff else { return nil }
            return HCPlotMark(date: date, value: row.weightLb)
        }.sorted { $0.date < $1.date }
    }
    private var best: Double { entries.map(\.weightLb).max() ?? 0 }
    private var totalVolume: Double {
        entries.reduce(0) { $0 + $1.weightLb * Double($1.reps) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                PremiumHeader(eyebrow: "STRENGTH / RECORDS", title: exercise,
                              subtitle: "Actual logged loads and repetitions.")
                HStack(spacing: 10) {
                    HCCard {
                        HCMetricBlock(label: "Heaviest logged",
                                      value: String(format: "%.1f lb", best))
                    }
                    HCCard {
                        HCMetricBlock(label: "Lifetime volume",
                                      value: String(format: "%.0f lb", totalVolume))
                    }
                }
                Picker("Time window", selection: $rangeDays) {
                    Text("7D").tag(7)
                    Text("30D").tag(30)
                    Text("90D").tag(90)
                }
                .pickerStyle(.segmented)
                if marks.isEmpty {
                    HCCard { Text("No recorded sets in this date range.")
                        .foregroundStyle(HCDesign.secondary) }
                } else {
                    HCCard {
                        Chart(marks) { point in
                            LineMark(x: .value("Day", point.date),
                                     y: .value("Weight (lb)", point.value))
                                .foregroundStyle(HCDesign.electric)
                            PointMark(x: .value("Day", point.date),
                                      y: .value("Weight (lb)", point.value))
                                .foregroundStyle(HCDesign.electric)
                        }
                        .frame(height: 215)
                    }
                }
                HCSectionTitle(title: "Logged sets", detail: "\(entries.count) entries")
                ForEach(Array(entries.prefix(45).enumerated()), id: \.offset) { _, row in
                    HCCard {
                        HStack {
                            Text(row.date)
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text(String(format: "%.1f lb × %d", row.weightLb, row.reps))
                                .font(.system(size: 13, weight: .semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationTitle(exercise)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Recovery: no invented WHOOP readiness

// MARK: - Recovery: personal baselines without invented clinical claims
private struct HCRecoverySignal: Identifiable {
    let id: String
    let label: String
    let symbol: String
    let source: String
    let date: String
    let current: Double
    let baseline: Double?
    let baselineLabel: String
    let unit: String
    let lowerIsWorse: Bool
    let alertEnabled: Bool
    let points: [HCPlotMark]

    var formattedValue: String {
        unit == "h" ? String(format: "%.1f h", current) :
        String(format: "%.0f %@", current, unit)
    }
    var percent: Double? {
        guard let baseline, baseline > 0 else { return nil }
        return (current - baseline) * 100 / baseline
    }
    var unfavorableMagnitude: Double? {
        guard let percent else { return nil }
        return lowerIsWorse ? -percent : percent
    }
    // Conservative *display thresholds*, not diagnostic ranges.
    var severity: Int {
        guard alertEnabled, let delta = unfavorableMagnitude else { return 0 }
        if delta > 25 { return 2 }
        if delta > 12 { return 1 }
        return 0
    }
    var color: Color {
        guard baseline != nil else { return HCDesign.secondary }
        return severity == 2 ? HCDesign.danger :
            severity == 1 ? HCDesign.caution : HCDesign.good
    }
    var comparison: String {
        guard let percent, let baseline else {
            return "More same-source history is needed for a reliable comparison."
        }
        let direction = percent < 0 ? "below" : "above"
        return "\(Int(abs(percent).rounded()))% \(direction) your \(baselineLabel) baseline " +
               "(\(String(format: "%.1f", baseline)) \(unit))"
    }
    var status: String {
        !alertEnabled ? "PERSONAL TREND" :
        baseline == nil ? "BASELINE PENDING" :
        severity == 2 ? "OUTSIDE RECENT PATTERN" :
        severity == 1 ? "WORTH WATCHING" : "NEAR YOUR BASELINE"
    }
    static func build(label: String, symbol: String, source: String,
                      unit: String, lowerIsWorse: Bool,
                      rows: [(String, Double)], suppliedBaseline: Double? = nil,
                      alertEnabled: Bool = true)
        -> HCRecoverySignal? {
        let unique = Dictionary(grouping: rows, by: { $0.0 })
            .compactMap { date, readings -> (String, Double)? in
                guard !readings.isEmpty else { return nil }
                let values = readings.map { $0.1 }.sorted()
                let middle = values.count / 2
                let median = values.count.isMultiple(of: 2)
                    ? (values[middle - 1] + values[middle]) / 2 : values[middle]
                return (date, median)
            }.sorted { $0.0 < $1.0 }
        guard let latest = unique.last,
              let anchor = HCPlanBuilder.startOfDate(latest.0) else { return nil }
        let earlier = unique.dropLast().compactMap { row -> (Double, Int)? in
            guard let day = HCPlanBuilder.startOfDate(row.0) else { return nil }
            let delta = Calendar.current.dateComponents([.day], from: day, to: anchor).day ?? 999
            return delta > 0 && delta <= 28 ? (row.1, delta) : nil
        }
        let seven = earlier.filter { $0.1 <= 7 }.map { $0.0 }
        let month = earlier.map { $0.0 }
        let baseline: Double? = {
            if seven.count >= 5 { return seven.reduce(0,+) / Double(seven.count) }
            if month.count >= 5 { return month.reduce(0,+) / Double(month.count) }
            if let suppliedBaseline, suppliedBaseline > 0 { return suppliedBaseline }
            return nil
        }()
        let baselineName = seven.count >= 5 ? "7-day" :
            month.count >= 5 ? "28-day" : "provider-supplied"
        return HCRecoverySignal(id: source + "-" + label, label: label, symbol: symbol,
                                source: source, date: latest.0, current: latest.1,
                                baseline: baseline, baselineLabel: baselineName,
                                unit: unit, lowerIsWorse: lowerIsWorse,
                                alertEnabled: alertEnabled,
                                points: unique.suffix(30).compactMap { row in
                                    HCPlanBuilder.startOfDate(row.0).map {
                                        HCPlotMark(date: $0, value: row.1)
                                    }
                                })
    }
}

/// Display identity only. These groups NEVER combine physiologically
/// different HRV measurement methods or merge samples across providers.
private struct HCMetricFamily: Identifiable {
    let id: String
    let title: String
    let readings: [HCRecoverySignal]

    var alerts: Int { readings.filter { $0.severity > 0 && $0.baseline != nil }.count }
    var isHRV: Bool { id == "hrv" }
    var sourceCount: Int {
        Set(readings.map { Self.sourceKey($0.source) }).count
    }

    static func sourceKey(_ name: String) -> String {
        let value = name.lowercased()
        if value.contains("whoop") { return "whoop" }
        if value.contains("apple watch") || value.contains("watch ultra") ||
           value.contains("watch series") { return "apple-watch" }
        if value.contains("garmin") { return "garmin" }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sourceName(_ name: String) -> String {
        switch sourceKey(name) {
        case "whoop": return "WHOOP"
        case "apple-watch": return "Apple Watch"
        case "garmin": return "Garmin"
        default: return name
        }
    }

    static func method(_ signal: HCRecoverySignal) -> String {
        guard familyID(signal) == "hrv" else { return signal.label }
        let label = signal.label.lowercased()
        if label.contains("rmssd") { return "RMSSD" }
        if label.contains("sdnn") { return "SDNN" }
        return "Unspecified HRV method"
    }

    static func familyID(_ signal: HCRecoverySignal) -> String {
        let text = signal.label.lowercased()
        if text.contains("hrv") || text.contains("heart rate variability") {
            return "hrv"
        }
        if text.contains("sleep") || text.contains("asleep") { return "sleep" }
        if text.contains("resting heart") { return "resting-heart-rate" }
        if text.contains("daily low hr") { return "daily-low-heart-rate" }
        if text.contains("respiratory rate") { return "respiratory-rate" }
        if text.contains("blood oxygen") || text.contains("oxygen saturation") ||
           text.contains("spo2") { return "blood-oxygen" }
        if text == "steps" || text == "step count" { return "steps" }
        if text == "heart rate" { return "heart-rate" }
        return "metric:" + text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func familyTitle(_ id: String, first: HCRecoverySignal) -> String {
        switch id {
        case "hrv": return "Heart rate variability"
        case "sleep": return "Sleep"
        case "resting-heart-rate": return "Resting heart rate"
        case "daily-low-heart-rate": return "Daily low heart rate"
        case "respiratory-rate": return "Respiratory rate"
        case "blood-oxygen": return "Blood oxygen"
        case "steps": return "Steps"
        case "heart-rate": return "Heart rate"
        default: return first.label
        }
    }

    static func build(from signals: [HCRecoverySignal]) -> [HCMetricFamily] {
        let families = Dictionary(grouping: signals, by: familyID)
        return families.compactMap { id, values -> HCMetricFamily? in
            // One row per canonical source *and method*. Repeated data flows
            // (e.g. WHOOP via HealthKit and a saved WHOOP snapshot) do not
            // produce duplicate cards or indistinguishable source rows.
            let bySourceAndMethod = Dictionary(grouping: values) {
                sourceKey($0.source) + "|" +
                (id == "hrv" ? method($0).lowercased() : "reading")
            }
            let entries = bySourceAndMethod.values.compactMap { duplicates in
                duplicates.sorted {
                    if $0.date != $1.date { return $0.date > $1.date }
                    if $0.points.count != $1.points.count {
                        return $0.points.count > $1.points.count
                    }
                    if ($0.baseline != nil) != ($1.baseline != nil) {
                        return $0.baseline != nil
                    }
                    return $0.label.localizedStandardCompare($1.label) == .orderedAscending
                }.first
            }.sorted {
                let leftSource = sourceName($0.source)
                let rightSource = sourceName($1.source)
                if leftSource != rightSource { return leftSource < rightSource }
                return method($0) < method($1)
            }
            guard let first = entries.first else { return nil }
            return HCMetricFamily(id: id, title: familyTitle(id, first: first),
                                  readings: entries)
        }.sorted { lhs, rhs in
            let order = [
                "sleep", "hrv", "resting-heart-rate", "respiratory-rate",
                "blood-oxygen", "daily-low-heart-rate", "steps", "heart-rate"
            ]
            let left = order.firstIndex(of: lhs.id) ?? 100
            let right = order.firstIndex(of: rhs.id) ?? 100
            return left == right ? lhs.title < rhs.title : left < right
        }
    }
}

/// Dedicated chart builder avoids a huge SwiftUI type-check expression in
/// the metric row and keeps a same-source baseline separate from other data.
private struct HCHealthTrendChart: View {
    let reading: HCRecoverySignal

    var body: some View {
        Chart {
            ForEach(reading.points) { point in
                LineMark(x: .value("Date", point.date),
                         y: .value("Reading", point.value))
                    .foregroundStyle(HCDesign.electric)
            }
            if let baseline = reading.baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(HCDesign.secondary.opacity(0.75))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.automatic)
        .frame(height: 120)
        .padding(.top, 6)
        .accessibilityLabel("Recent \(reading.label) from \(reading.source)")
    }
}

/// One understated metric surface, with source-attributed readings inside.
/// Never presents a blended HRV or "combined" sleep value.
/// Provider-specific analysis; HRV SDNN and RMSSD are never combined.
private struct IMUNHealthMetricDetail: View {
    let reading: HCRecoverySignal
    @State private var windowDays = 30

    private var points: [HCPlotMark] {
        let cutoff = Calendar.current.date(byAdding: .day,
                                           value: -windowDays, to: Date()) ?? .distantPast
        return reading.points.filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }
    private var rangeAverage: Double? {
        guard !points.isEmpty else { return nil }
        return points.reduce(0) { $0 + $1.value } / Double(points.count)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 17) {
                PremiumHeader(eyebrow: "HEALTH / METRIC", title: reading.label,
                              subtitle: HCMetricFamily.sourceName(reading.source) +
                                  " · Same-source history only")
                HCCard(accent: HCDesign.electric) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(reading.formattedValue)
                            .font(HCDesign.display(38))
                            .monospacedDigit()
                        Text("Recorded " + reading.date + " · " + reading.source)
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                        Text(reading.comparison)
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                Picker("History", selection: $windowDays) {
                    Text("7D").tag(7)
                    Text("30D").tag(30)
                    Text("90D").tag(90)
                }
                .pickerStyle(.segmented)
                HCCard {
                    VStack(alignment: .leading, spacing: 12) {
                        if points.count > 1 {
                            Chart {
                                ForEach(points) { point in
                                    LineMark(x: .value("Date", point.date),
                                             y: .value("Value", point.value))
                                        .foregroundStyle(HCDesign.electric)
                                }
                                if let baseline = reading.baseline {
                                    RuleMark(y: .value("Personal baseline", baseline))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                        .foregroundStyle(HCDesign.secondary)
                                }
                            }
                            .frame(height: 226)
                        } else {
                            Text("More same-source readings are needed for a trend.")
                                .font(.system(size: 13))
                                .foregroundStyle(HCDesign.secondary)
                                .frame(maxWidth: .infinity, minHeight: 80)
                        }
                        if let average = rangeAverage {
                            HCMetricBlock(label: "Period average",
                                          value: String(format: "%.1f %@", average, reading.unit))
                        }
                        if let baseline = reading.baseline {
                            Text("\(reading.baselineLabel) personal baseline: " +
                                 String(format: "%.1f %@", baseline, reading.unit))
                                .font(.system(size: 12))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                Text("Readings are informational, not diagnostic. Values from different devices or HRV methods are not blended.")
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationTitle(reading.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HCMetricFamilyCard: View {
    let family: HCMetricFamily
    @Binding var expandedTrends: Set<String>
    @AppStorage("hcSelectedHealthMetric") private var selectedHealthMetric = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(family.title)
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundStyle(HCDesign.ink)
                Spacer(minLength: 8)
                Text("\(family.sourceCount) SOURCE\(family.sourceCount == 1 ? "" : "S")")
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .tracking(0.6)
                    .foregroundStyle(HCDesign.secondary)
            }
            .padding(.bottom, 14)

            ForEach(Array(family.readings.enumerated()), id: \.offset) { index, reading in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(HCMetricFamily.sourceName(reading.source))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(HCDesign.ink)
                            if family.isHRV {
                                Text(HCMetricFamily.method(reading))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(HCDesign.secondary)
                            } else if family.id == "sleep" && reading.label != "Sleep" {
                                Text(reading.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        Text(reading.formattedValue)
                            .font(.system(size: 23, weight: .semibold, design: .default))
                            .monospacedDigit()
                            .foregroundStyle(HCDesign.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Text(reading.comparison)
                        .font(.system(size: 12))
                        .foregroundStyle(reading.severity > 0 && reading.baseline != nil
                            ? HCDesign.caution : HCDesign.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    NavigationLink {
                        IMUNHealthMetricDetail(reading: reading)
                    } label: {
                        Label("View history and personal baseline",
                              systemImage: "chart.xyaxis.line")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(HCDesign.electric)
                    HStack {
                        Text(reading.date)
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                        Spacer()
                        if reading.points.count > 1 {
                            Button {
                                selectedHealthMetric = family.title + " / " + reading.label
                                if expandedTrends.contains(reading.id) {
                                    expandedTrends.remove(reading.id)
                                } else {
                                    expandedTrends.insert(reading.id)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(expandedTrends.contains(reading.id) ?
                                         "Hide trend" : "View trend")
                                    Image(systemName: expandedTrends.contains(reading.id) ?
                                          "chevron.up" : "chevron.down")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(HCDesign.electric)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if expandedTrends.contains(reading.id) && reading.points.count > 1 {
                        HCHealthTrendChart(reading: reading)
                    }
                }
                .padding(.vertical, 11)
                if index < family.readings.count - 1 {
                    Rectangle()
                        .fill(HCDesign.outline.opacity(0.4))
                        .frame(height: 1)
                }
            }

            if family.isHRV {
                Text("RMSSD and SDNN are different HRV methods. Each source and method has its own history and baseline.")
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
                    .padding(.top, 13)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HCDesign.card,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(HCDesign.outline.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct HCHealthSummaryStat: View {
    let value: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .default))
                .monospacedDigit()
                .foregroundStyle(HCDesign.ink)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(HCDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The top of Health shows real source-specific readings, not synthetic
/// readiness or combined WHOOP/Apple Watch measurements.
private struct HCHealthQuickMetric: View {
    let title: String
    let reading: HCRecoverySignal?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.65)
                .foregroundStyle(HCDesign.secondary)
            Text(reading?.formattedValue ?? "—")
                .font(.system(size: 22, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(IMUNStyle.animationsEnabled ?
                           .easeOut(duration: 0.16) : nil,
                           value: reading?.formattedValue ?? "—")
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(HCDesign.ink)
            Text(reading.map {
                HCMetricFamily.sourceName($0.source) + " · " + $0.date
            } ?? "No reading available")
                .font(.system(size: 10))
                .foregroundStyle(HCDesign.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(12)
        .background(HCDesign.card, in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(HCDesign.outline.opacity(0.4), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HCHealthCategoryGroup: Identifiable {
    let name: String
    let families: [HCMetricFamily]
    var id: String { name }
}


private struct IMUNWearableIntelligenceCard: View {
    @ObservedObject var health: HCAppleHealthReader
    @Binding var primary: String
    @State private var report = IMUNWearableIntelligence.analyze([], primary: "Auto")
    @State private var details = false

    private var sources: [String] {
        Array(Set(["WHOOP", "Apple Watch", "Garmin", "Chargerless", primary]
            .filter { $0 != "Auto" } +
            health.metrics.map { IMUNDataProvenance.provider($0.source) })).sorted()
    }
    private func update() {
        report = IMUNWearableIntelligence.analyze(
            health.heartRateObservations, primary: primary)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IMUN  /  SENSOR INTELLIGENCE")
                        .font(HCDesign.label(9))
                        .tracking(1.4)
                        .foregroundStyle(HCDesign.aqua)
                    Text("Wearable intelligence")
                        .font(HCDesign.display(21))
                        .foregroundStyle(HCDesign.ink)
                    Text("The evidence behind every measurement.")
                        .font(.system(size: 12))
                        .foregroundStyle(HCDesign.secondary)
                }
                Spacer()
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 23, weight: .light))
                    .foregroundStyle(HCDesign.electric)
            }
            HStack {
                Text("PRIMARY WEARABLE")
                    .font(HCDesign.label(10))
                    .foregroundStyle(HCDesign.secondary)
                Spacer()
                Picker("Primary wearable", selection: $primary) {
                    Text("Automatic").tag("Auto")
                    ForEach(sources, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .tint(HCDesign.electric)
            }
            Divider().overlay(HCDesign.outline)
            Text(report.summary)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HCDesign.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(report.sources.count)").font(HCDesign.metric(23))
                    Text("Sources").font(HCDesign.label(10))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(report.alignedWindows)").font(HCDesign.metric(23))
                    Text("Aligned windows").font(HCDesign.label(10))
                }
                Spacer()
            }
            .foregroundStyle(HCDesign.ink)
            if !report.sources.isEmpty {
                DisclosureGroup(isExpanded: $details) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(report.sources) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.source).font(.system(size: 12, weight: .semibold))
                                    Text("\(item.uniqueMinutes) sampled minutes · \(item.comparedSamples) paired" +
                                         (item.unusualJumps > 0 ? " · \(item.unusualJumps) rapid changes" : ""))
                                        .font(.system(size: 10))
                                        .foregroundStyle(HCDesign.secondary)
                                }
                                Spacer(minLength: 8)
                                Text("\(item.sampleCount) samples")
                                    .font(HCDesign.label(10))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                        ForEach(report.agreements) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.first + " / " + item.second)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("\(item.pairs) windows · \(Int(item.nearAgreementPercent.rounded()))% within 5 bpm")
                                        .font(.system(size: 10))
                                        .foregroundStyle(HCDesign.secondary)
                                }
                                Spacer(minLength: 8)
                                Text(String(format: "%.1f bpm", item.medianDifferenceBPM))
                                    .font(HCDesign.metric(15))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Text("Review sensor agreement")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HCDesign.electric)
                }
                .tint(HCDesign.electric)
            }
            Text("Agreement ≠ accuracy. Aligned samples are compared within 30 seconds over the past 48 hours. The selected primary guides EITAN; other sources remain available for comparison. Data stays on-device until you choose to share with IsAIah.")
                .font(.system(size: 10))
                .foregroundStyle(HCDesign.secondary)
        }
        .padding(16)
        .background(HCDesign.card,
                    in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(HCDesign.outline, lineWidth: 1))
        .onAppear(perform: update)
        .onReceive(health.$heartRateObservations) { _ in
            DispatchQueue.main.async { update() }
        }
        .onChange(of: primary) { _, _ in update() }
    }
}

private struct PremiumRecoveryPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @ObservedObject var appleHealth: HCAppleHealthReader
    @State private var showHistory = false
    @State private var showRawReadings = false
    @AppStorage("hcSelectedHealthCategory") private var selectedHealthCategory = "Overview"
    @AppStorage("hcSelectedHealthMetric") private var selectedHealthMetric = ""
    @AppStorage("hcEitanPrimaryWearable") private var preferredSource = "Auto"
    @State private var metricSearch = ""
    @State private var expandedTrends: Set<String> = []
    @State private var expandedHealthGroups: Set<String> = ["Sleep", "Heart & Vitals"]
    // Trends and baselines are expensive; only rebuild when source records
    // change, rather than every scrolling/layout pass on the Health tab.
    @State private var cachedSignals: [HCRecoverySignal] = []

    private let categoryOrder = ["Heart & Vitals", "Sleep", "Activity & Energy",
                                 "Running & Cycling", "Mobility",
                                 "Body Measurements", "Metabolic & Nutrition", "Workouts"]
    private var healthCategories: [String] {
        let found = Set(appleHealth.metrics.map(\.category))
        let main = categoryOrder.filter { found.contains($0) }
        let whoop = (appleHealth.metrics.contains {
            $0.source.localizedCaseInsensitiveContains("whoop")
        } || coach.recoveryHistory.contains {
            $0.source.localizedCaseInsensitiveContains("whoop")
        }) ? ["WHOOP"] : []
        return ["Overview", "All"] + whoop + main
    }

    private func filteredSignals(from signals: [HCRecoverySignal]) -> [HCRecoverySignal] {
        let groupFiltered: [HCRecoverySignal]
        switch selectedHealthCategory {
        case "Overview":
            groupFiltered = signals.filter {
                let name = $0.label.lowercased()
                return name.contains("hrv") ||
                       name.contains("heart rate variability") ||
                       name.contains("sleep") || name.contains("asleep") ||
                       name.contains("resting heart") || name.contains("respiratory") ||
                       name.contains("blood oxygen") || name.contains("daily low hr")
            }
        case "All":
            groupFiltered = signals
        case "Sleep":
            groupFiltered = signals.filter {
                HCMetricFamily.familyID($0) == "sleep"
            }
        case "WHOOP":
            groupFiltered = signals.filter {
                $0.source.localizedCaseInsensitiveContains("whoop")
            }
        default:
            let names = Set(appleHealth.metrics.filter {
                $0.category == selectedHealthCategory
            }.map(\.name))
            groupFiltered = signals.filter { names.contains($0.label) }
        }
        let searched = metricSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return (searched.isEmpty ? groupFiltered : groupFiltered.filter {
            $0.label.localizedCaseInsensitiveContains(searched) ||
            $0.source.localizedCaseInsensitiveContains(searched) ||
            (searched.lowercased() == "hrv" &&
             HCMetricFamily.familyID($0) == "hrv") ||
            (searched.lowercased() == "blood oxygen" &&
             HCMetricFamily.familyID($0) == "blood-oxygen")
        }).sorted { $0.date > $1.date }
    }


    private func rebuildSignalCache() {
        cachedSignals = signals
    }

    private var signals: [HCRecoverySignal] {
        var result: [HCRecoverySignal] = []
        let grouped = Dictionary(grouping: coach.recoveryHistory, by: \.source)
        for source in grouped.keys.sorted() {
            guard let items = grouped[source] else { continue }
            let newest = items.sorted { $0.date > $1.date }.first
            if let metric = HCRecoverySignal.build(
                label: "HRV · RMSSD", symbol: "waveform.path.ecg",
                source: source, unit: "ms", lowerIsWorse: true,
                rows: items.compactMap { item in item.hrvMS.map { (item.date, $0) } },
                suppliedBaseline: newest?.hrvBaselineMS) { result.append(metric) }
            if let metric = HCRecoverySignal.build(
                label: "Sleep", symbol: "moon.zzz.fill", source: source,
                unit: "h", lowerIsWorse: true,
                rows: items.compactMap { item in
                    item.sleepSeconds.map { (item.date, $0 / 3600) }
                }) { result.append(metric) }
            if let metric = HCRecoverySignal.build(
                label: "Daily low HR", symbol: "heart.fill", source: source,
                unit: "bpm", lowerIsWorse: false,
                rows: items.compactMap { item in item.dailyLowHR.map { (item.date, $0) } }
            ) { result.append(metric) }
        }
        // Group samples once rather than scanning the full history for every
        // metric whenever SwiftUI evaluates the Health screen.
        let sampleGroups = Dictionary(grouping: appleHealth.metricHistory) {
            $0.name + "\u{001F}" + $0.source
        }
        for metric in appleHealth.metrics {
            let samples = sampleGroups[metric.name + "\u{001F}" + metric.source] ?? []
            if let signal = HCRecoverySignal.build(
                label: metric.name,
                symbol: metric.category == "Sleep" ? "moon.zzz.fill" :
                    metric.category == "Activity & Energy" ? "figure.walk" :
                    metric.category == "Running & Cycling" ? "figure.run" :
                    metric.category == "Metabolic & Nutrition" ? "leaf.fill" :
                    "waveform.path.ecg",
                source: metric.source,
                unit: metric.unit,
                lowerIsWorse: metric.lowerIsWorse,
                rows: samples.map { ($0.date, $0.value) },
                alertEnabled: metric.lowerIsWorse || metric.higherIsWorse
            ) { result.append(signal) }
        }
        return result.sorted { $0.date > $1.date }
    }

    private func latestReading(for id: String,
                               families: [HCMetricFamily]) -> HCRecoverySignal? {
        let readings = families.first(where: { $0.id == id })?.readings ?? []
        let filtered = preferredSource == "Auto" ? readings : readings.filter {
            HCMetricFamily.sourceName($0.source) == preferredSource
        }
        return filtered.sorted { $0.date > $1.date }.first
    }

    @ViewBuilder
    private func quickMetric(_ name: String, key: String,
                             families: [HCMetricFamily]) -> some View {
        if let reading = latestReading(for: key, families: families) {
            NavigationLink {
                IMUNHealthMetricDetail(reading: reading)
            } label: {
                HCHealthQuickMetric(title: name, reading: reading)
            }
            .buttonStyle(.plain)
        } else {
            HCHealthQuickMetric(title: name, reading: nil)
        }
    }

    private func category(for family: HCMetricFamily) -> String {
        switch family.id {
        case "sleep": return "Sleep"
        case "hrv", "heart-rate", "resting-heart-rate", "daily-low-heart-rate",
             "respiratory-rate", "blood-oxygen": return "Heart & Vitals"
        default:
            for reading in family.readings {
                if let match = appleHealth.metrics.first(where: { $0.name == reading.label }) {
                    return match.category
                }
            }
            return "Recovery & Other"
        }
    }

    private func categorized(_ families: [HCMetricFamily]) -> [HCHealthCategoryGroup] {
        let grouped = Dictionary(grouping: families) { category(for: $0) }
        let priority = categoryOrder + ["Recovery & Other"]
        return grouped.keys.sorted {
            let lhs = priority.firstIndex(of: $0) ?? priority.count
            let rhs = priority.firstIndex(of: $1) ?? priority.count
            return lhs == rhs ? $0 < $1 : lhs < rhs
        }.map { HCHealthCategoryGroup(name: $0, families: grouped[$0] ?? []) }
    }

    // Filters remain visible when the title and metrics scroll off-screen.
    // Keeping the selector compact avoids a second oversized header.
    private var stickyMetricFilters: some View {
        VStack(spacing: 7) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(healthCategories, id: \.self) { category in
                        Button {
                            selectedHealthCategory = category
                        } label: {
                            Text(category)
                                .font(.system(size: 11, weight:
                                    selectedHealthCategory == category ? .semibold : .medium))
                                .foregroundStyle(selectedHealthCategory == category ?
                                                 HCDesign.ink : HCDesign.secondary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(selectedHealthCategory == category ?
                                            HCDesign.raised : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedHealthCategory == category ?
                                                [.isSelected] : [])
                    }
                }
            }
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(HCDesign.secondary)
                TextField("Find metric or source", text: $metricSearch)
                    .font(.system(size: 12))
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Search health measurements")
                if !metricSearch.isEmpty {
                    Button {
                        metricSearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(HCDesign.secondary)
                    }
                    .accessibilityLabel("Clear metric search")
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(HCDesign.raised, in: RoundedRectangle(cornerRadius: 9))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(HCDesign.canvas)
        .overlay(alignment: .bottom) {
            Rectangle().fill(HCDesign.outline.opacity(0.45)).frame(height: 0.5)
        }
    }

    var body: some View {
        let allSignals = cachedSignals
        let allFamilies = HCMetricFamily.build(from: allSignals)
        let visibleFamilies = HCMetricFamily.build(
            from: filteredSignals(from: allSignals))
        let sourceCount = Set(allSignals.map {
            HCMetricFamily.sourceKey($0.source)
        }).count
        let baselines = allFamilies.filter {
            $0.readings.contains(where: { $0.baseline != nil })
        }.count
        let changed = allFamilies.filter { $0.alerts > 0 }.count

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("IMUN  /  HEALTH")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.7)
                            .foregroundStyle(HCDesign.secondary)
                        Spacer()
                        Text(Date().formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    .padding(.bottom, 8)
                    Text("Health.")
                        .font(HCDesign.display(31))
                        .tracking(-0.8)
                        .foregroundStyle(HCDesign.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Your measurements, their sources, and the patterns that matter.")
                        .font(.system(size: 14))
                        .foregroundStyle(HCDesign.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 5)

                Rectangle()
                    .fill(HCDesign.outline.opacity(0.55))
                    .frame(height: 1)

                IMUNAppleHealthConnectionCard(appleHealth: appleHealth,
                                               compact: true)

                HStack(alignment: .top, spacing: 12) {
                    HCHealthSummaryStat(value: "\(allFamilies.count)",
                                        title: "Metrics")
                    HCHealthSummaryStat(value: "\(sourceCount)",
                                        title: "Sources")
                    HCHealthSummaryStat(value: "\(baselines)",
                                        title: "With baselines")
                }

                HCSectionTitle(title: "At a glance", detail: "Latest available readings")
                if appleHealth.loading && allFamilies.isEmpty {
                    IMUNLoadingPlaceholder(lines: 4, height: 170)
                        .transition(.opacity)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10)],
                              spacing: 10) {
                        quickMetric("Sleep", key: "sleep", families: allFamilies)
                        quickMetric("HRV", key: "hrv", families: allFamilies)
                        quickMetric("Resting HR", key: "resting-heart-rate", families: allFamilies)
                        quickMetric("Steps", key: "steps", families: allFamilies)
                    }
                    .transition(.opacity)
                }
                if changed > 0 {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(HCDesign.caution)
                        Text("\(changed) metric\(changed == 1 ? "" : "s") differ from recent same-source patterns. Review the marked readings below.")
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }

                IMUNWearableIntelligenceCard(health: appleHealth,
                                            primary: $preferredSource)
                HCSectionTitle(title: "Measurements",
                               detail: selectedHealthCategory == "Overview" ?
                                    "At a glance" : selectedHealthCategory)
                if appleHealth.loading && allFamilies.isEmpty {
                    IMUNLoadingPlaceholder(lines: 3, height: 138)
                    IMUNLoadingPlaceholder(lines: 2, height: 104)
                } else if visibleFamilies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(allFamilies.isEmpty ?
                             "No measurements available yet" : "No matching measurements")
                            .font(.system(size: 17, weight: .semibold))
                        Text(allFamilies.isEmpty ?
                             "Connect Apple Health or a supported data source to see measured values here." :
                             "Try another source or clear the search.")
                            .font(.system(size: 13))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 28)
                }

                if selectedHealthCategory == "All" {
                    ForEach(categorized(visibleFamilies)) { group in
                        DisclosureGroup(isExpanded: Binding(
                            get: { expandedHealthGroups.contains(group.name) },
                            set: { expanded in
                                if expanded { expandedHealthGroups.insert(group.name) }
                                else { expandedHealthGroups.remove(group.name) }
                            }
                        )) {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(group.families) { family in
                                    HCMetricFamilyCard(family: family,
                                                       expandedTrends: $expandedTrends)
                                }
                            }
                            .padding(.top, 12)
                        } label: {
                            HStack {
                                Text(group.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(HCDesign.ink)
                                Spacer()
                                Text("\(group.families.count) metrics")
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                        .tint(HCDesign.electric)
                        .padding(13)
                        .background(HCDesign.card,
                                    in: RoundedRectangle(cornerRadius: 13))
                    }
                } else {
                    ForEach(visibleFamilies) { family in
                        HCMetricFamilyCard(family: family,
                                           expandedTrends: $expandedTrends)
                    }
                }

                HCSectionTitle(title: "Data sources", detail: "Manage & inspect")
                    .padding(.top, 7)
                HCCard {
                    VStack(alignment: .leading, spacing: 13) {
                        Text("Your measurements stay attributed to the device or provider that recorded them. Missing metrics are not estimated.")
                            .font(.system(size: 13))
                            .foregroundStyle(HCDesign.secondary)
                        HStack(spacing: 10) {
                            HCOutlineButton(title: appleHealth.loading ?
                                            "Reading…" : "Refresh readings",
                                            icon: "arrow.clockwise") {
                                appleHealth.refreshIfAuthorized(force: true)
                            }
                        }
                        if appleHealth.loading {
                            ProgressView().tint(HCDesign.electric)
                        }
                        Divider().overlay(HCDesign.outline.opacity(0.35))

                        DisclosureGroup(isExpanded: $showRawReadings) {
                            ForEach(appleHealth.metrics.filter { metric in
                                (selectedHealthCategory == "All" ||
                                 selectedHealthCategory == "Overview" ||
                                 (selectedHealthCategory == "WHOOP" &&
                                  metric.source.localizedCaseInsensitiveContains("whoop")) ||
                                 metric.category == selectedHealthCategory) &&
                                (metricSearch.isEmpty ||
                                 metric.name.localizedCaseInsensitiveContains(metricSearch) ||
                                 metric.source.localizedCaseInsensitiveContains(metricSearch))
                            }) { metric in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(metric.name)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("\(metric.source) · \(metric.date)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(HCDesign.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    Text(metric.value)
                                        .font(.system(size: 14, weight: .semibold))
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 5)
                            }
                        } label: {
                            Text("Individual Apple Health readings")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .tint(HCDesign.electric)

                        DisclosureGroup(isExpanded: $showHistory) {
                            ForEach(Array(coach.recoveryHistory.prefix(14))) { item in
                                HStack(spacing: 8) {
                                    Text("\(item.date) · \(item.source)")
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.hrvMS.map {
                                        String(format: "%.0f ms", $0)
                                    } ?? "—")
                                        .monospacedDigit()
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(HCDesign.secondary)
                                .padding(.vertical, 4)
                            }
                        } label: {
                            Text("Imported recovery history")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .tint(HCDesign.electric)

                        Link("WHOOP → Apple Health setup",
                             destination: URL(
                                string: "https://support.whoop.com/s/article/Apple-Health-Integration")!)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(HCDesign.electric)
                    }
                }
                Text("Comparisons require repeated observations from the same source and measurement method. HRV RMSSD and SDNN are shown separately; neither is treated as the other's equivalent. These trends are informational, not diagnostic.")
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .safeAreaInset(edge: .top, spacing: 0) { stickyMetricFilters }
        .animation(IMUNStyle.animationsEnabled ? .easeOut(duration: 0.18) : nil,
                   value: appleHealth.loading)
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HCDesign.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onChange(of: selectedHealthCategory) { _, _ in
            // Avoid describing a stale metric after switching health sections.
            selectedHealthMetric = ""
        }
        .onAppear {
            rebuildSignalCache()
            // Reopening Health should not trigger another 35-day HealthKit
            // scan if the existing source snapshot is still fresh.
            appleHealth.refreshIfAuthorized()
        }
        .onReceive(appleHealth.$metricHistory) { _ in
            // HealthKit publishes the entire batch once, with metrics already
            // updated. Rebuilding on both arrays duplicates expensive work.
            DispatchQueue.main.async { rebuildSignalCache() }
        }
        .onReceive(coach.$recoveryHistory) { _ in
            DispatchQueue.main.async { rebuildSignalCache() }
        }
    }
}

// MARK: - Coaching, export and settings

// Chat is the home of Coach. The training calendar and settings sit beneath it.
private struct PremiumCoachPage: View {
    let launchContext: String
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @State private var movingSession: HCPlannedSession?
    @State private var showUpcomingSessions = false

    private var days: [Date] {
        let start = Calendar.current.startOfDay(for: Date())
        return (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: start)
        }
    }
    private var sessionsThisWeek: Int {
        let dates = Set(days.map { HCPlanBuilder.dateString($0) })
        return coach.plannedSessions.filter { dates.contains($0.date) }.count
    }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("IMUN / COACH")
                                .font(HCDesign.label(10))
                                .tracking(1.5)
                                .foregroundStyle(HCDesign.aqua)
                            HStack(spacing: 12) {
                                IMUNIsaiahMark(size: 44)
                                IMUNIsaiahWordmark(size: 29)
                            }
                            .padding(8)
                            .background(IMUNIsaiahBrand.graphite,
                                        in: RoundedRectangle(cornerRadius: 12))
                            Text("Your training. One conversation.")
                                .font(.system(size: 13))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }

                    if !coach.signedIn {
                        PremiumLogin()
                    }

                    PremiumCoachConversation(launchContext: launchContext)
                        .id("imun-coach-chat")

                    DisclosureGroup(isExpanded: $showUpcomingSessions) {
                        HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Your next 7 days")
                                .font(HCDesign.display(24))
                                .foregroundStyle(HCDesign.ink)
                            Text("A look at the training ahead.")
                                .font(.system(size: 12))
                                .foregroundStyle(HCDesign.secondary)
                        }
                        Spacer()
                        Text("\(sessionsThisWeek) PLANNED")
                            .font(HCDesign.label(10))
                            .tracking(0.6)
                            .foregroundStyle(HCDesign.aqua)
                    }
                    .padding(.top, 4)

                    VStack(spacing: 10) {
                        ForEach(Array(days.enumerated()), id: \.element) { index, day in
                            let dateKey = HCPlanBuilder.dateString(day)
                            let sessions = coach.plannedSessions
                                .filter { $0.date == dateKey }
                            HStack(alignment: .top, spacing: 12) {
                                VStack(spacing: 3) {
                                    Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                                        .font(HCDesign.label(10))
                                        .foregroundStyle(index == 0 ?
                                                         HCDesign.electric : HCDesign.secondary)
                                    Text(day.formatted(.dateTime.day()))
                                        .font(HCDesign.metric(22))
                                        .foregroundStyle(HCDesign.ink)
                                }
                                .frame(width: 45)
                                .padding(.top, 4)

                                Rectangle()
                                    .fill(index == 0 ? HCDesign.electric : HCDesign.outline)
                                    .frame(width: 2)

                                VStack(alignment: .leading, spacing: 8) {
                                    if sessions.isEmpty {
                                        Text(!coach.signedIn ? "Sign in to see your plan" :
                                             coach.loading ? "Loading your plan…" :
                                             "No session planned")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(HCDesign.secondary)
                                            .padding(.vertical, 8)
                                    } else {
                                        ForEach(sessions) { session in
                                            Button {
                                                movingSession = session
                                            } label: {
                                                HStack(spacing: 10) {
                                                    Image(systemName: sessionSymbol(session.kind))
                                                        .font(.system(size: 16))
                                                        .foregroundStyle(sessionColor(session.kind))
                                                        .frame(width: 29)
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(session.title)
                                                            .font(.system(size: 14, weight: .semibold))
                                                            .foregroundStyle(HCDesign.ink)
                                                            .multilineTextAlignment(.leading)
                                                            .fixedSize(horizontal: false, vertical: true)
                                                        Text(session.completed ? "Completed" :
                                                             sessionLabel(session.kind))
                                                            .font(.system(size: 11))
                                                            .foregroundStyle(HCDesign.secondary)
                                                    }
                                                    Spacer(minLength: 4)
                                                    Image(systemName: session.completed ?
                                                        "checkmark.circle.fill" : "chevron.right")
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(session.completed ?
                                                                         HCDesign.good :
                                                                         HCDesign.secondary)
                                                }
                                                .padding(.vertical, 6)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("\(session.title), \(day.formatted(date: .abbreviated, time: .omitted))")
                                            if session.id != sessions.last?.id {
                                                Divider().overlay(HCDesign.outline)
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 2)
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 13)
                            .background(index == 0 ?
                                HCDesign.electric.opacity(0.075) : HCDesign.card,
                                in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(index == 0 ?
                                    HCDesign.electric.opacity(0.3) :
                                    HCDesign.outline.opacity(0.7), lineWidth: 1))
                        }
                    }

                    HStack {
                        Text("Tap a session to view or move its date.")
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundStyle(HCDesign.aqua)
                    }

                    } label: {
                        HStack {
                            Text("Upcoming sessions")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Text("\(sessionsThisWeek) PLANNED")
                                .font(HCDesign.label(10))
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                    .tint(HCDesign.secondary)
                    .padding(16)
                    .background(HCDesign.card, in: RoundedRectangle(cornerRadius: 13))
                    Spacer(minLength: 25)
                }
                .padding(.horizontal, 18)
                .padding(.top, 9)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .hcPage()
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $movingSession) { session in
                IMUNMoveWorkoutSheet(entry: session)
                    .environmentObject(coach)
            }
    }

    private func sessionSymbol(_ kind: String) -> String {
        let normalized = kind.lowercased()
        if normalized.contains("run") { return "figure.run" }
        if normalized.contains("lift") || normalized.contains("strength") {
            return "dumbbell.fill"
        }
        if normalized.contains("cycl") || normalized.contains("bike") {
            return "bicycle"
        }
        return "figure.mixed.cardio"
    }
    private func sessionColor(_ kind: String) -> Color {
        kind.lowercased().contains("run") ? HCDesign.aqua : HCDesign.electric
    }
    private func sessionLabel(_ kind: String) -> String {
        let normalized = kind.lowercased()
        if normalized.contains("run") { return "Running" }
        if normalized.contains("lift") || normalized.contains("strength") {
            return "Weightlifting"
        }
        return kind.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

// All original settings, exports and integrations are preserved here.
// Real on-screen AI conversation. The model is called only on explicit Send.
// The server uses the signed-in user's JWT; provider credentials stay server-side.
private struct IMUNCoachTurn: Identifiable, Codable {
    var id: UUID = UUID()
    let role: String
    let text: String
}

/// Private, locally stored conversation memory. This is retrieval, not
/// on-device model training. Nothing is uploaded until the athlete taps Send.
private enum IMUNCoachLocalMemory {
    private static var archiveURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask).first?
            .appendingPathComponent("imun-isaiah-conversation-memory.json")
    }

    private static func read() -> [IMUNCoachTurn] {
        guard let archiveURL,
              let data = try? Data(contentsOf: archiveURL),
              let value = try? JSONDecoder().decode([IMUNCoachTurn].self, from: data)
        else { return [] }
        return value
    }

    static var count: Int { read().count }

    static func save(_ recent: [IMUNCoachTurn]) {
        guard !recent.isEmpty, let archiveURL else { return }
        var history = read()
        var seen = Set(history.map(\.id))
        for turn in recent where seen.insert(turn.id).inserted {
            history.append(turn)
        }
        guard let data = try? JSONEncoder().encode(Array(history.suffix(1000)))
        else { return }
        do {
            try FileManager.default.createDirectory(
                at: archiveURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try data.write(to: archiveURL, options: .atomic)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: archiveURL.path)
        } catch {
            // A failed archive must never prevent training or live chat.
        }
    }

    static func clear() {
        guard let archiveURL else { return }
        try? FileManager.default.removeItem(at: archiveURL)
    }

    static func relevantUserNotes(for question: String,
                                  excluding inCurrentThread: Set<UUID>) -> String {
        let stopWords: Set<String> = [
            "what", "when", "where", "which", "about", "could", "would",
            "should", "have", "this", "that", "with", "from", "your",
            "mine", "please", "then", "them", "there", "like",
            "workout", "workouts", "training"
        ]
        let terms = Set(question.lowercased().split {
            !$0.isLetter && !$0.isNumber
        }.map(String.init).filter { $0.count >= 4 }).subtracting(stopWords)
        let messages = read().filter {
            $0.role == "user" && !inCurrentThread.contains($0.id)
        }
        let candidates = messages.enumerated().map { index, note in
            (index: index, text: note.text,
             hits: terms.filter { note.text.lowercased().contains($0) }.count)
        }
        let related = candidates.filter { $0.hits > 0 }.sorted {
            if $0.hits != $1.hits { return $0.hits > $1.hits }
            return $0.index > $1.index
        }
        var selected = related.prefix(10).map { $0 }
        // Include a few recent athlete statements for changing goals/preferences,
        // even if the current question uses different wording.
        let recent = candidates.suffix(5).reversed()
        for note in recent where !selected.contains(where: { $0.index == note.index }) {
            selected.append(note)
        }
        guard !selected.isEmpty else { return "" }
        let snippets = selected.prefix(14).map {
            "Athlete previously said: " + String($0.text.prefix(420))
        }.joined(separator: "\n")
        return String(snippets.prefix(5500))
    }
}

/// Understated, accessible activity indicator for both action planning and
/// generated answers. Driven by TimelineView; no manual timers to leak.
private struct IMUNIsAIahThinking: View {
    let phase: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.42)) { tick in
            let active = Int(tick.date.timeIntervalSince1970 / 0.42) % 3
            HStack(spacing: 11) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(HCDesign.electric.opacity(index == active ? 1 : 0.22))
                            .frame(width: 5, height: 5)
                    }
                }
                Text(phase)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HCDesign.secondary)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("IsAIah is thinking")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(HCDesign.card, in: RoundedRectangle(cornerRadius: 12))
    }
}

// A compact evidence chart for questions about measured running progress.
// This is calculated locally from imported, attributed workouts. The chart
// is never fabricated by a language model and never shows missing pace as 0.
private struct IMUNCoachRunPaceEvidence: View {
    let runs: [HCProgressRun]
    let includeAppleHealth: Bool

    private struct Point: Identifiable {
        let id: String
        let date: Date
        let paceMinutes: Double
        let source: String
    }

    private var points: [Point] {
        let measured: [Point] = runs.compactMap { run in
            guard includeAppleHealth || !run.fromAppleHealth,
                  let distance = run.distanceMeters, distance >= 800,
                  let elapsed = run.durationSeconds, elapsed > 0,
                  let date = HCPlanBuilder.startOfDate(run.date)
            else { return nil }
            let pace = elapsed / 60 / (distance / 1609.344)
            guard pace.isFinite && pace >= 4 && pace <= 30 else { return nil }
            return Point(id: run.id, date: date,
                         paceMinutes: pace, source: run.source)
        }
        return Array(measured.sorted { $0.date < $1.date }.suffix(14))
    }

    var body: some View {
        let observations = points
        if observations.count >= 3 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("RECORDED RUNNING PACE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.0)
                    Spacer()
                    Text("\(observations.count) runs")
                        .font(.system(size: 11))
                }
                .foregroundStyle(HCDesign.secondary)
                Chart(observations) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Pace (min/mi)", point.paceMinutes)
                    )
                    .foregroundStyle(HCDesign.aqua)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Pace (min/mi)", point.paceMinutes)
                    )
                    .foregroundStyle(HCDesign.aqua)
                    .symbolSize(25)
                }
                .frame(height: 166)
                Text("Minutes per mile · lower is faster. Different routes, effort and recording sources are not directly comparable.")
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Sources: " +
                     Set(observations.map(\.source)).sorted().joined(separator: ", "))
                    .font(.system(size: 10))
                    .foregroundStyle(HCDesign.secondary)
            }
            .padding(15)
            .background(HCDesign.card,
                        in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// The VO2-max graph uses real, same-source historical readings.
/// Never join estimates from different watch vendors into a single trend.
private struct IMUNCoachVO2Evidence: View {
    let samples: [HCHealthTrendSample]

    private struct Point: Identifiable {
        let id: String
        let date: Date
        let value: Double
    }

    private var selectedSource: (String, [Point])? {
        let readings = samples.filter {
            ($0.name.localizedCaseInsensitiveContains("VO₂") ||
             $0.name.localizedCaseInsensitiveContains("VO2")) &&
            $0.value.isFinite && $0.value > 10 && $0.value < 95
        }
        let grouped = Dictionary(grouping: readings, by: \.source)
        guard let source = grouped.keys.sorted().max(by: {
            (grouped[$0]?.count ?? 0) < (grouped[$1]?.count ?? 0)
        }), let rows = grouped[source], rows.count >= 3 else { return nil }
        let ordered: [Point] = rows.compactMap { row in
            guard let day = HCPlanBuilder.startOfDate(row.date) else { return nil }
            return Point(id: row.id, date: day, value: row.value)
        }.sorted { $0.date < $1.date }
        guard ordered.count >= 3 else { return nil }
        return (source, Array(ordered.suffix(24)))
    }

    var body: some View {
        if let (source, observations) = selectedSource {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("VO₂ MAX · RECORDED TREND")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                    Spacer()
                    Text("\(observations.count) readings")
                        .font(.system(size: 11))
                }
                .foregroundStyle(HCDesign.secondary)
                Chart(observations) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("VO2 max", point.value)
                    )
                    .foregroundStyle(HCDesign.aqua)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("VO2 max", point.value)
                    )
                    .foregroundStyle(HCDesign.aqua)
                    .symbolSize(24)
                }
                .frame(height: 160)
                Text("mL/kg/min · " + source +
                     ". Device-estimated aerobic fitness; compare with consistent methods.")
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(15)
            .background(HCDesign.card,
                        in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// A real conversation surface, not a backend diagnostics panel. Chats remain
// on the phone. Nothing is transmitted until the athlete chooses Send.
private struct PremiumCoachConversation: View {
    let launchContext: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @EnvironmentObject private var appleHealth: HCAppleHealthReader
    @EnvironmentObject private var runImporter: HCRunHealthImporter
    @AppStorage("hcSelectedHealthCategory") private var selectedHealthCategory = "Overview"
    @AppStorage("hcSelectedHealthMetric") private var selectedHealthMetric = ""
    @AppStorage("hcAIShareRecovery") private var shareRecovery = false
    @AppStorage("hcIsaiahRememberChats") private var rememberChats = true
    @AppStorage("hcCoachConversationLocalV1") private var storedConversation = Data()
    @FocusState private var composerFocused: Bool
    @State private var question = ""
    @State private var pendingAttachments: [IMUNCoachAttachment] = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var attachmentError: String?
    @State private var turns: [IMUNCoachTurn] = []
    @State private var isSending = false
    @State private var thinkingPhase = "IsAIah is thinking"
    @State private var errorMessage: String?
    @State private var pendingAction: IMUNCoachActionProposal?
    @State private var selectedActionWorkoutID = ""
    @State private var actionMoveDate = Date()
    @AppStorage("hcDesignPreset") private var designPreset = "techno"
    @AppStorage("hcSelectedTab") private var selectedTab = "training"
    @AppStorage("hcTrainingActivity") private var selectedActivity = "weightlifting"
    @AppStorage("hcMotivationSource") private var motivationSource = "off"
    @AppStorage("hcRestOverrideSeconds") private var restSeconds = 0
    @AppStorage("hcWatchHaptics") private var watchHaptics = true
    @AppStorage("hcRunVoiceCues") private var runVoiceCues = false
    @AppStorage("hcRunAutoLaps") private var runAutoLaps = true
    @State private var actionWorkoutTitle = "Custom Strength Workout"
    @State private var actionRunMinutes = 40
    @State private var actionRunHasHR = false
    @State private var actionRunMinHR = 120
    @State private var actionRunMaxHR = 150
    @State private var actionEditOperation: IMUNCoachExerciseOperation = .update
    @State private var selectedEditExerciseID = ""
    @State private var actionEditExerciseName = ""
    @State private var actionEditInstructions = ""
    @State private var actionEditSets = 3
    @State private var actionEditRepMin = 8
    @State private var actionEditRepMax = 12
    @State private var actionEditRestSeconds = 120
    @State private var actionEditWeightText = ""
    @State private var actionWorkoutSignature = ""
    @State private var actionPreferenceKey = "hcDesignMode"
    @State private var actionPreferenceValue = "system"

    private var context: String {
        turns.suffix(6).map { turn in
            (turn.role == "user" ? "Athlete: " : "IsAIah: ") + turn.text
        }.joined(separator: "\n")
    }
    private var canSend: Bool {
        coach.signedIn && !isSending &&
        (!question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
         !pendingAttachments.isEmpty)
    }

    private var shouldShowRunEvidence: Bool {
        guard let latestQuestion = turns.last(where: { $0.role == "user" }) else {
            return false
        }
        let text = latestQuestion.text.lowercased()
        return ["run", "pace", "endurance", "aerobic", "fitness",
                "vo2", "vo₂", "plateau", "progress"]
            .contains(where: { text.contains($0) })
    }


    // Full-height chat with an anchored composer. Scrolling can never bury Send.
    var body: some View {
        VStack(spacing: 0) {
            isaiahBanner
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if turns.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("What can I help with?")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle(HCDesign.ink)
                                Text("Ask naturally about this screen, your training or your health.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(HCDesign.secondary)
                                suggestion("Is my running fitness improving since September?")
                                suggestion("Are my legs tired from recent training?")
                                suggestion("Compare my training load and recovery this week")
                                suggestion("Review today's workout")
                            }
                            .padding(.vertical, 14)
                        }

                        ForEach(turns) { turn in
                            HStack(alignment: .bottom, spacing: 9) {
                                if turn.role == "user" {
                                    Spacer(minLength: 35)
                                } else {
                                    IMUNIsaiahMark(size: 29)
                                }
                                Text(turn.text)
                                    .font(.system(size: 14))
                                    .foregroundStyle(HCDesign.ink)
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(turn.role == "user" ?
                                                HCDesign.electric.opacity(0.14) :
                                                HCDesign.card,
                                                in: RoundedRectangle(cornerRadius: 16))
                                if turn.role != "user" { Spacer(minLength: 35) }
                            }
                        }
                        if !isSending && turns.last?.role == "assistant" {
                            if shouldShowRunEvidence {
                                IMUNCoachRunPaceEvidence(runs: coach.runHistory,
                                                         includeAppleHealth: shareRecovery)
                                if shareRecovery {
                                    IMUNCoachVO2Evidence(samples: appleHealth.metricHistory)
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    followUp("Compare my running progress over 8 weeks")
                                    followUp("Is fatigue affecting my performance?")
                                    followUp("What should I adjust tomorrow?")
                                }
                                .padding(.vertical, 3)
                            }
                        }
                        if isSending {
                            IMUNIsAIahThinking(phase: thinkingPhase)
                                .id("isaiah-thinking")
                        }
                if let action = pendingAction {
                    IMUNCoachActionReviewCard(
                        action: action,
                        selectedWorkoutID: $selectedActionWorkoutID,
                        moveDate: $actionMoveDate,
                        workoutTitle: $actionWorkoutTitle,
                        runMinutes: $actionRunMinutes,
                        runHasHR: $actionRunHasHR,
                        runMinBPM: $actionRunMinHR,
                        runMaxBPM: $actionRunMaxHR,
                        editOperation: $actionEditOperation,
                        selectedEditExerciseID: $selectedEditExerciseID,
                        editExerciseName: $actionEditExerciseName,
                        editInstructions: $actionEditInstructions,
                        editSets: $actionEditSets,
                        editRepMin: $actionEditRepMin,
                        editRepMax: $actionEditRepMax,
                        editRestSeconds: $actionEditRestSeconds,
                        editWeightText: $actionEditWeightText,
                        preferenceKey: $actionPreferenceKey,
                        preferenceValue: $actionPreferenceValue,
                        onSelectEditExercise: { id in
                            populateEditFields(for: id, hint: nil)
                        },
                        canConfirm: canConfirmAction(action),
                        onCancel: { pendingAction = nil },
                        onConfirm: { confirmAction(action) }
                    )
                }


                        if !coach.signedIn {
                            Text("Sign in to message IsAIah.")
                                .font(.system(size: 12))
                                .foregroundStyle(HCDesign.caution)
                        }
                        if let errorMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("IsAIah couldn't respond.")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HCDesign.caution)
                                Text(errorMessage)
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                        Color.clear.frame(height: 1).id("lastCoachMessage")
                    }
                    .padding(.horizontal, 17)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: turns.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("lastCoachMessage", anchor: .bottom)
                    }
                }
                .onChange(of: isSending) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("lastCoachMessage", anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HCDesign.canvas.ignoresSafeArea())
        .toolbarBackground(IMUNIsaiahBrand.graphite, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .onAppear {
            if let decoded = try? JSONDecoder().decode([IMUNCoachTurn].self,
                                                       from: storedConversation) {
                turns = Array(decoded.suffix(24))
                if rememberChats { IMUNCoachLocalMemory.save(turns) }
            }
            // Refresh all authorized Apple Health workout types, including
            // older records, before answering history questions.
            runImporter.startIfAuthorized()
        }
        .task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            composerFocused = true
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { composerFocused = false }
            }
        }
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls.prefix(4) {
                    do {
                        try addAttachment(IMUNCoachAttachmentReader.document(at: url))
                    } catch {
                        attachmentError = error.localizedDescription
                    }
                }
            case .failure(let error):
                attachmentError = error.localizedDescription
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self)
                    else { throw IMUNCoachAttachmentReader.Failure.invalidImage }
                    let uploaded = try IMUNCoachAttachmentReader.image(
                        data: data, filename: "Training photo.jpg")
                    try addAttachment(uploaded)
                } catch {
                    attachmentError = error.localizedDescription
                }
                selectedPhoto = nil
            }
        }
    }

    private func addAttachment(_ item: IMUNCoachAttachment) throws {
        guard pendingAttachments.count < 4,
              item.kind != "image" ||
                pendingAttachments.filter({ $0.kind == "image" }).count < 2
        else { throw IMUNCoachAttachmentReader.Failure.tooMany }
        pendingAttachments.append(item)
        attachmentError = nil
    }

    // One slim assistant toolbar replaces both the oversized artwork banner
    // and the extra iOS navigation bar, maximizing the conversation viewport.
    private var isaiahBanner: some View {
        HStack(spacing: 10) {
            IMUNIsaiahArtwork(layout: .full)
                .frame(width: 121, height: 26)
                .accessibilityLabel("IsAIah")
            Spacer(minLength: 2)
            HStack(spacing: 4) {
                Circle()
                    .fill(HCDesign.electric)
                    .frame(width: 4, height: 4)
                Text((launchContext.components(separatedBy: "\n").first ??
                      "iMun").replacingOccurrences(of: "Screen: ", with: ""))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(HCDesign.secondary)
            .accessibilityLabel("Current screen: " +
                (launchContext.components(separatedBy: "\n").first ?? "iMun"))
            if !turns.isEmpty {
                Button {
                    turns.removeAll()
                    storedConversation = Data()
                    pendingAction = nil
                    errorMessage = nil
                    composerFocused = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .frame(width: 25, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New IsAIah conversation")
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 27, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close IsAIah")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .foregroundStyle(HCDesign.secondary)
        .background(IMUNIsaiahBrand.graphite)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HCDesign.electric.opacity(0.2))
                .frame(height: 0.5)
        }
    }

    private var composer: some View {
        VStack(spacing: 9) {
            if !pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(pendingAttachments) { item in
                            HStack(spacing: 6) {
                                Image(systemName: item.kind == "image" ?
                                      "photo" : "doc.text")
                                Text(item.name).lineLimit(1)
                                Button {
                                    pendingAttachments.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove " + item.name)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(HCDesign.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(HCDesign.raised,
                                        in: Capsule())
                        }
                    }
                }
            }
            if let attachmentError {
                Text(attachmentError)
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.caution)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 6) {
                Button {
                    showFileImporter = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 31, height: 43)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach a workout file")
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 31, height: 43)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach a training photo")
                TextField("Message IsAIah…", text: $question, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .submitLabel(.send)
                    .font(.system(size: 15))
                    .tint(HCDesign.electric)
                    .foregroundStyle(HCDesign.ink)
                    .padding(.leading, 14)
                    .padding(.vertical, 11)
                    .onSubmit { if canSend { send() } }
                    .accessibilityLabel("Message IsAIah")
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(canSend ? Color.white : HCDesign.secondary)
                        .frame(width: 43, height: 43)
                        .background(canSend ?
                                    Color(red: 0.13, green: 0.47, blue: 0.97) :
                                    HCDesign.raised,
                                    in: Circle())
                }
                .disabled(!canSend)
                .buttonStyle(.plain)
                .accessibilityLabel("Send message to IsAIah")
                .padding(5)
            }
            .background(HCDesign.card,
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(HCDesign.outline, lineWidth: 1)
            }
            Toggle(isOn: $shareRecovery) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.text.square")
                    Text("Share Apple Health workouts & recovery")
                    Spacer(minLength: 0)
                    if shareRecovery {
                        Text("\(runImporter.workouts.count) workouts")
                            .foregroundStyle(HCDesign.electric)
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(HCDesign.secondary)
            }
            .tint(HCDesign.electric)
            if shareRecovery && runImporter.workouts.isEmpty &&
                !runImporter.refreshing {
                HStack(spacing: 9) {
                    Text("No Apple Health workout history loaded yet.")
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                    Spacer(minLength: 4)
                    Button("Connect") {
                        appleHealth.connect(onRequestCompleted: {
                            runImporter.startIfAuthorized()
                        })
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HCDesign.aqua)
                }
            }
            Toggle("Use relevant previous IsAIah chats", isOn: $rememberChats)
                .font(.system(size: 11))
                .tint(HCDesign.electric)
                .foregroundStyle(HCDesign.secondary)
                .onChange(of: rememberChats) { _, enabled in
                    if enabled { IMUNCoachLocalMemory.save(turns) }
                }

        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(HCDesign.canvas)
        .overlay(alignment: .top) {
            Rectangle().fill(HCDesign.outline).frame(height: 1)
        }
    }

    private func followUp(_ text: String) -> some View {
        Button {
            question = text
            composerFocused = true
        } label: {
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(HCDesign.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(HCDesign.raised,
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func suggestion(_ text: String) -> some View {
        Button {
            question = text
            composerFocused = true
        } label: {
            HStack(spacing: 12) {
                Text(text)
                    .foregroundStyle(HCDesign.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HCDesign.secondary)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(HCDesign.raised.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func persist() {
        if let saved = try? JSONEncoder().encode(Array(turns.suffix(24))) {
            storedConversation = saved
        }
        if rememberChats { IMUNCoachLocalMemory.save(turns) }
    }

    private func populateEditFields(for exerciseID: String,
                                    hint: IMUNCoachWorkoutEditHint?) {
        guard let exercise = coach.workout?.exercises.first(where: {
            $0.id == exerciseID
        }) else { return }
        actionEditSets = hint?.sets ?? exercise.prescribedSets
        actionEditRepMin = hint?.repMin ?? exercise.repMin
        actionEditRepMax = max(actionEditRepMin, hint?.repMax ?? exercise.repMax)
        actionEditRestSeconds = hint?.restSeconds ?? exercise.restSeconds
        actionEditWeightText = (hint?.weightLb ?? exercise.suggestedWeightLb)
            .map { String($0) } ?? ""
        if hint == nil {
            actionEditInstructions = exercise.instructions ?? ""
        }
    }

    private func prepareEditFields(_ proposed: IMUNCoachActionProposal) {
        actionWorkoutSignature = coach.workout?.coachEditSignature ?? ""
        let hint = proposed.workoutEdit
        actionEditOperation = hint?.operation ?? .update
        actionEditExerciseName = ""
        actionEditInstructions = ""
        actionEditSets = hint?.sets ?? 3
        actionEditRepMin = hint?.repMin ?? 8
        actionEditRepMax = max(actionEditRepMin, hint?.repMax ?? 12)
        actionEditRestSeconds = hint?.restSeconds ?? 120
        actionEditWeightText = hint?.weightLb.map { String($0) } ?? ""
        let matches = coach.workout?.exercises.filter {
            guard let name = hint?.exerciseName?.lowercased() else { return false }
            return $0.name.lowercased() == name ||
                $0.name.localizedCaseInsensitiveContains(name)
        } ?? []
        selectedEditExerciseID = matches.count == 1 ? (matches.first?.id ?? "") : ""
        if actionEditOperation == .add {
            actionEditExerciseName = hint?.exerciseName ?? ""
        } else if actionEditOperation == .replace {
            actionEditExerciseName = hint?.newName ?? ""
        }
        if !selectedEditExerciseID.isEmpty &&
           actionEditOperation != .add {
            populateEditFields(for: selectedEditExerciseID, hint: hint)
        }
    }

    private var validExerciseEditInputs: Bool {
        guard (1...12).contains(actionEditSets),
              (1...30).contains(actionEditRepMin),
              (actionEditRepMin...40).contains(actionEditRepMax),
              (15...360).contains(actionEditRestSeconds),
              actionEditRestSeconds.isMultiple(of: 15) else { return false }
        let raw = actionEditWeightText.trimmingCharacters(
            in: .whitespacesAndNewlines)
        return raw.isEmpty || Double(raw).map {
            $0.isFinite && (0...1500).contains($0)
        } == true
    }

    private func canConfirmAction(_ action: IMUNCoachActionProposal) -> Bool {
        guard coach.signedIn else { return false }
        switch action.kind {
        case .moveWorkout:
            guard let selected = coach.plannedSessions.first(where: {
                $0.id == selectedActionWorkoutID
            }) else { return false }
            return coach.movingWorkoutID == nil &&
                selected.date != HCPlanBuilder.dateString(actionMoveDate)
        case .createStrength:
            return coach.workout == nil &&
                !actionWorkoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .createRun:
            return coach.runPlan == nil &&
                !actionWorkoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                (1...360).contains(actionRunMinutes) &&
                (!actionRunHasHR ||
                 ((35...230).contains(actionRunMinHR) &&
                  (35...230).contains(actionRunMaxHR) &&
                  actionRunMinHR <= actionRunMaxHR))
        case .renameStrength:
            return coach.workout != nil &&
                !actionWorkoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .editStrength:
            guard let plan = coach.workout,
                  plan.id == action.suggestedWorkoutID,
                  plan.date == HCPlanBuilder.dateString(Date()),
                  !actionWorkoutSignature.isEmpty,
                  plan.coachEditSignature == actionWorkoutSignature,
                  validExerciseEditInputs else { return false }
            if actionEditOperation == .add {
                let name = actionEditExerciseName.trimmingCharacters(
                    in: .whitespacesAndNewlines)
                return !name.isEmpty && plan.exercises.count < 35 &&
                    !plan.exercises.contains(where: {
                        $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
                    })
            }
            guard let selected = plan.exercises.first(where: {
                $0.id == selectedEditExerciseID
            }) else { return false }
            if actionEditOperation == .replace {
                return !actionEditExerciseName.trimmingCharacters(
                    in: .whitespacesAndNewlines).isEmpty &&
                    !coach.completedSets(for: plan).contains(where: {
                        $0.exerciseID == selected.id
                    })
            }
            if actionEditOperation == .remove {
                return !coach.completedSets(for: plan).contains(where: {
                    $0.exerciseID == selected.id
                })
            }
            return true
        case .undoSet:
            return coach.lastUndoableSet != nil
        case .undoWorkout:
            return coach.phoneSessionStartedAt != nil && coach.workout != nil
        case .completeRun:
            return coach.runPlan?.id == action.suggestedWorkoutID &&
                coach.runPlan?.isCompleted == false
        case .completeScheduledWorkout:
            return coach.completingWorkoutID == nil &&
                coach.plannedSessions.contains(where: {
                    $0.id == selectedActionWorkoutID && !$0.completed &&
                    UUID(uuidString: $0.id) != nil
                })
        case .setTheme:
            return action.themeID.flatMap(IMUNPreset.init(rawValue:)) != nil
        case .setRestDuration:
            return action.parameter.flatMap(Int.init).map {
                [0, 60, 90, 120, 180].contains($0)
            } ?? false
        case .setMotivation:
            return action.parameter.map {
                ["off", "scripture", "original", "performance", "custom"].contains($0)
            } ?? false
        case .setAppPreference:
            guard let preference = IMUNCoachPreference.byID(actionPreferenceKey)
            else { return false }
            return preference.choices.contains(actionPreferenceValue)
        case .setWatchHaptics, .setRunVoiceCues, .setRunAutoLaps:
            return action.parameter == "on" || action.parameter == "off"
        case .selectTraining:
            return action.parameter == "run" || action.parameter == "weightlifting"
        case .openTab:
            return action.parameter.map {
                ["training", "health", "progress", "coach", "settings"].contains($0)
            } ?? false
        case .syncWatch:
            return true
        }
    }

    private func confirmAction(_ action: IMUNCoachActionProposal) {
        guard canConfirmAction(action) else {
            errorMessage = "The planned change is no longer valid. Refresh the app and review it again."
            return
        }
        let reply: String
        switch action.kind {
        case .moveWorkout:
            guard let workout = coach.plannedSessions.first(where: {
                $0.id == selectedActionWorkoutID
            }) else { return }
            coach.moveWorkout(workout, to: actionMoveDate)
            reply = "Requested the move of \(workout.title) to \(HCPlanBuilder.dateString(actionMoveDate)). iMun will apply it only if the calendar server accepts it."
        case .undoSet:
            guard let set = coach.lastUndoableSet else { return }
            coach.undoSet(set.id)
            reply = "Undid set \(set.index) of \(set.exerciseName). Progress is updated locally and the correction is queued for sync."
        case .undoWorkout:
            guard coach.phoneSessionStartedAt != nil else { return }
            coach.undoPhoneWorkout()
            reply = "The active workout was undone. Your prescribed plan is still available, and the correction is queued for sync."
        case .completeRun:
            coach.setRunManuallyCompleted(true)
            reply = "Recorded your confirmation of today's completed run. No sensor measurements were invented."
        case .completeScheduledWorkout:
            guard let selected = coach.plannedSessions.first(where: {
                $0.id == selectedActionWorkoutID && !$0.completed
            }) else { return }
            coach.completePlannedWorkout(selected)
            reply = "Requested a manual calendar completion for \(selected.title). The change is recorded only if the server confirms it; no performance data will be created."
        case .syncWatch:
            coach.refreshAndSendToWatch()
            reply = "Requested today's training plan to sync over iMun's phone and cloud connections."
        case .setTheme:
            guard let theme = action.themeID else { return }
            designPreset = theme
            coach.publishDesignToCloud()
            reply = "Changed the visual theme to \(IMUNPreset(rawValue: theme)?.title ?? theme)."
        case .createStrength:
            coach.newWorkout(date: Date(), title: actionWorkoutTitle)
            selectedActivity = "weightlifting"
            selectedTab = "training"
            reply = "Created a custom strength workout with no fabricated sets. Open Training to add your exercises."
        case .createRun:
            guard coach.createRunToday(
                title: actionWorkoutTitle, minutes: actionRunMinutes,
                minimumBPM: actionRunHasHR ? actionRunMinHR : nil,
                maximumBPM: actionRunHasHR ? actionRunMaxHR : nil)
            else {
                errorMessage = coach.status
                return
            }
            selectedActivity = "run"
            selectedTab = "training"
            reply = "Created today's \(actionRunMinutes)-minute run with your selected targets and queued it for iMun Watch."
        case .renameStrength:
            guard let workout = coach.workout else { return }
            coach.saveEditedWorkout(HCWorkout(id: workout.id, date: workout.date,
                sessionKey: workout.sessionKey, title: actionWorkoutTitle,
                exercises: workout.exercises, isPreview: false))
            reply = "Saved the requested strength workout name without changing exercises or completed sets."
        case .editStrength:
            guard let workout = coach.workout else { return }
            let rawWeight = actionEditWeightText.trimmingCharacters(
                in: .whitespacesAndNewlines)
            let edit = IMUNCoachWorkoutEdit(
                workoutID: workout.id,
                expectedSignature: actionWorkoutSignature,
                operation: actionEditOperation,
                exerciseID: actionEditOperation == .add ? nil : selectedEditExerciseID,
                newName: actionEditExerciseName,
                newInstructions: actionEditInstructions.trimmingCharacters(
                    in: .whitespacesAndNewlines).isEmpty ?
                    nil : actionEditInstructions,
                sets: actionEditSets,
                repMin: actionEditRepMin,
                repMax: actionEditRepMax,
                restSeconds: actionEditRestSeconds,
                suggestedWeightLb: rawWeight.isEmpty ? nil : Double(rawWeight))
            guard let result = coach.applyCoachWorkoutEdit(edit) else {
                errorMessage = coach.status
                return
            }
            reply = result
        case .selectTraining:
            guard let activity = action.parameter else { return }
            selectedActivity = activity
            selectedTab = "training"
            reply = "Opened the \(activity == "run" ? "Running" : "Strength") training view."
        case .openTab:
            guard let destination = action.parameter else { return }
            selectedTab = destination
            reply = destination == "coach" ?
                "Opened IsAIah." : "Opened the \(destination.capitalized) tab."
        case .setMotivation:
            guard let source = action.parameter else { return }
            motivationSource = source
            reply = "Updated motivation to \(source). It remains separate from your visual theme."
        case .setAppPreference:
            guard let result = IMUNCoachPreference.apply(
                id: actionPreferenceKey, value: actionPreferenceValue) else {
                errorMessage = "That setting is not available or the value is invalid."
                return
            }
            if actionPreferenceKey.hasPrefix("hcDesign") {
                coach.publishDesignToCloud()
            }
            coach.sendToWatch()
            reply = result
        case .setRestDuration:
            guard let value = action.parameter.flatMap(Int.init) else { return }
            restSeconds = value
            coach.sendToWatch()
            reply = value == 0 ? "Rest duration now follows your prescribed workout." :
                "Rest timer changed to \(value) seconds."
        case .setWatchHaptics:
            let value = action.parameter == "on"
            watchHaptics = value
            coach.sendToWatch()
            reply = "Watch haptics turned \(value ? "on" : "off")."
        case .setRunVoiceCues:
            let value = action.parameter == "on"
            runVoiceCues = value
            coach.sendToWatch()
            reply = "Running voice cues turned \(value ? "on" : "off")."
        case .setRunAutoLaps:
            let value = action.parameter == "on"
            runAutoLaps = value
            coach.sendToWatch()
            reply = "Automatic running laps turned \(value ? "on" : "off")."
        }
        turns.append(IMUNCoachTurn(role: "assistant", text: reply))
        pendingAction = nil
        errorMessage = nil
        persist()
    }

    private func presentAction(_ proposed: IMUNCoachActionProposal,
                               for originalRequest: String,
                               appendUser: Bool) {
        if appendUser {
            turns.append(IMUNCoachTurn(role: "user", text: originalRequest))
        }
        turns.append(IMUNCoachTurn(
            role: "assistant",
            text: "I can prepare that change. Review the exact details below and confirm before iMun applies it."))
        pendingAction = proposed
        selectedActionWorkoutID = proposed.suggestedWorkoutID ?? ""
        actionMoveDate = proposed.suggestedDate ?? Date()
        actionWorkoutTitle = proposed.kind == .createRun ? "Easy Run" :
            (proposed.parameter ?? "Custom Strength Workout")
        actionRunMinutes = Int(proposed.parameter ?? "") ?? 40
        actionRunHasHR = false
        actionPreferenceKey = proposed.settingKey ?? "hcDesignMode"
        actionPreferenceValue = IMUNCoachPreference.byID(actionPreferenceKey)
            .flatMap { setting in
                proposed.parameter.flatMap { requested in
                    setting.choices.contains(requested) ? requested : nil
                } ?? setting.choices.first
            } ?? "system"
        prepareEditFields(proposed)
        isSending = false
        errorMessage = nil
        persist()
    }

    // This is added to the remote chat ONLY after the athlete enables the
    // separately visible Health-sharing toggle and actively taps Send.
    private var eitanSharedCoachContext: String {
        guard let snapshot = coach.eitanSnapshot,
              snapshot.date == HCPlanBuilder.dateString(Date()),
              (UserDefaults.standard.object(forKey: "hcEitanEnabled") as? Bool ?? true),
              (UserDefaults.standard.object(forKey: "hcEitanUseHealth") as? Bool ?? true),
              (UserDefaults.standard.object(forKey: "hcEitanCoachingEnabled") as? Bool ?? true)
        else { return "" }
        let observations = snapshot.factors.map {
            "\($0.title): \($0.value)/100 (\($0.detail))"
        }.joined(separator: "; ")
        let primary = UserDefaults.standard.string(forKey: "hcEitanPrimaryWearable") ?? "Auto"
        return "\nPRIMARY WEARABLE FOR EITAN: " + primary +
            ". The primary wearable controls EITAN baselines. IsAIah should compare all user-shared wearable sources, keeping methods and source identities distinct; never silently substitute missing primary data or merge HRV methods. " +
            "\nEITAN observational body-wellness score: " +
            (snapshot.value.map(String.init) ?? "insufficient data") +
            "/100. Consecutive lower-score days: \(snapshot.consecutiveLowDays). " +
            "Coverage: \(snapshot.coverage). Factors: \(observations). " +
            "Suggestions: \(snapshot.coaching). " +
            (snapshot.coachingPlan.map { plan in
                "IsAIah training approach: \(plan.mode), \(plan.title). " +
                "Observed: \(plan.recordedTrainingStreak) consecutive recorded training days, " +
                "\(plan.recentHardDays) high-effort days in seven days, " +
                "\(plan.shortSleepNights.map(String.init) ?? "insufficient data") short-sleep nights across " +
                "\(plan.observedSleepNights) observed nights. Evidence confidence: \(plan.confidence). " +
                "Reasons: \(plan.reasons.joined(separator: "; ")). " +
                "Training suggestions: \(plan.cues.joined(separator: "; ")). "
            } ?? "") +
            "A single poor night does not require rest; adapt to warm-up feel, RIR and actual performance. " +
            "Sustained strain matters more than any one biomarker. " +
            "Suggest graduated training changes, easy activity, adequate sleep or rest when warranted; " +
            "do not automatically change the plan or promise injury prevention. " +
            "EITAN is not a validated clinical readiness or illness-risk model."
    }

    private func send() {
        let originalDraft = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        let uploads = pendingAttachments
        let questionText = originalDraft.isEmpty ?
            "Please analyze the attached exercise data. Explain what you can verify and what is missing." :
            originalDraft
        let userDisplayText = uploads.isEmpty ? questionText :
            questionText + "\nAttachments: " + uploads.map(\.name).joined(separator: ", ")
        if uploads.isEmpty && (questionText.lowercased().contains("what can you control") ||
           questionText.lowercased().contains("what can you do in imun") ||
           questionText.lowercased().contains("what actions can you")) {
            question = ""
            composerFocused = false
            turns.append(IMUNCoachTurn(role: "user", text: questionText))
            turns.append(IMUNCoachTurn(role: "assistant",
                text: IMUNCoachActionCatalog.userFacingSummary))
            persist()
            return
        }
        if uploads.isEmpty, let proposed = IMUNCoachActionInterpreter.propose(
            questionText, sessions: coach.plannedSessions,
            workout: coach.workout, run: coach.runPlan) {
            question = ""
            composerFocused = false
            errorMessage = nil
            presentAction(proposed, for: questionText, appendUser: true)
            return
        }
        let currentHistory = context
        let past = rememberChats ? IMUNCoachLocalMemory.relevantUserNotes(
            for: questionText, excluding: Set(turns.map(\.id))) : ""
        let history = [currentHistory, past].filter { !$0.isEmpty }
            .joined(separator: "\n")
        question = ""
        composerFocused = false
        errorMessage = nil
        isSending = true
        thinkingPhase = "IsAIah is thinking"
        turns.append(IMUNCoachTurn(role: "user", text: userDisplayText))
        persist()
        Task {
            // The service is a language classifier only: it cannot mutate
            // workouts, choose an unvalidated ID, or bypass confirmation.
            if uploads.isEmpty &&
                IMUNCoachActionInterpreter.mightNeedModelProposal(questionText) {
                await MainActor.run { thinkingPhase = "Reviewing your request" }
                if let classification = try? await coach.classifyIMUNCoachAction(
                    request: questionText, screenContext: launchContext),
                   let proposal = IMUNCoachActionInterpreter.proposalFromModel(
                    classification, sessions: coach.plannedSessions,
                    workout: coach.workout, run: coach.runPlan) {
                    await MainActor.run {
                        presentAction(proposal, for: questionText, appendUser: false)
                    }
                    return
                }
            }
            await MainActor.run { thinkingPhase = "Composing a response" }
            do {
                let reply = try await coach.askIMUNCoach(
                    question: questionText,
                    shareRecovery: shareRecovery,
                    recentConversation: history,
                    screenContext: launchContext,
                    healthSnapshot: shareRecovery ?
                        (appleHealth.isaiahHealthSnapshot(
                            selectedCategory: selectedHealthCategory,
                            selectedMetric: selectedHealthMetric,
                            question: questionText,
                            primaryWearable: UserDefaults.standard.string(
                                forKey: "hcEitanPrimaryWearable") ?? "Auto") +
                         eitanSharedCoachContext) : "",
                    attachments: uploads)
                await MainActor.run {
                    pendingAttachments.removeAll()
                    turns.append(IMUNCoachTurn(role: "assistant", text: reply))
                    isSending = false
                    persist()
                }
            } catch {
                await MainActor.run {
                    // Restore the draft without keeping a duplicate failed turn.
                    if turns.last?.role == "user" {
                        turns.removeLast()
                    }
                    question = originalDraft
                    errorMessage = error.localizedDescription
                    isSending = false
                    persist()
                }
            }
        }
    }
}

/// Explicit, strictly attributed physiological source for EITAN and the
/// opt-in IsAIah context. Tredict remains available for training history.
private struct HCEitanPrimaryWearableSelector: View {
    @EnvironmentObject private var appleHealth: HCAppleHealthReader
    @Binding var primaryWearable: String

    private var choices: [String] {
        Array(Set(["WHOOP", "Apple Watch", "Garmin", "Chargerless", primaryWearable]
            .filter { $0 != "Auto" } +
            appleHealth.metrics.map { IMUNDataProvenance.provider($0.source) })).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("PRIMARY WEARABLE")
                .font(HCDesign.label(10))
                .foregroundStyle(HCDesign.secondary)
            Picker("Primary wearable", selection: $primaryWearable) {
                Text("Automatic").tag("Auto")
                ForEach(choices, id: .self) { source in
                    Text(source).tag(source)
                }
            }
            .pickerStyle(.menu)
            .tint(HCDesign.electric)
            Text("Primary controls EITAN's physiological baseline. IsAIah can compare all authorized sources with separate baselines when sharing is enabled. No silent EITAN fallback.")
                .font(.system(size: 11))
                .foregroundStyle(HCDesign.secondary)
            if primaryWearable == "WHOOP" {
                Text("WHOOP exports sleep, resting HR and respiratory rate to Apple Health when enabled, but NOT WHOOP HRV (RMSSD). WHOOP HRV needs a separate authorized WHOOP API integration; Apple Watch HRV will not be substituted.")
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
            }
            Text("Tredict stays connected for running plans, workouts and historical training. Tredict/Garmin recovery history does not become EITAN's active wearable.")
                .font(.system(size: 11))
                .foregroundStyle(HCDesign.secondary)
        }
    }
}

/// Kept separate from the large Settings view for fast SwiftUI type-checking.
private struct HCEitanCloudSyncControls: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @Binding var consent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Toggle(isOn: $consent) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Private EITAN cloud sync")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Use when Apple Watch says Phone not connected. Optional: publish today's EITAN score, derived factors and coaching summary to your private iMun account for the signed-in Watch to download over the internet.")
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                }
            }
            .tint(HCDesign.electric)
            Text(consent
                 ? "Both devices must use the same iMun account. Switching this off clears the stored EITAN health snapshot when your iPhone can reach the cloud."
                 : "Off by default. EITAN stays on-device; regular workout cloud sync is unaffected.")
                .font(.system(size: 11))
                .foregroundStyle(HCDesign.secondary)
            Text(coach.eitanCloudSyncStatus)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(HCDesign.electric)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                coach.refreshEitanCloudSync(force: true)
            } label: {
                Label(consent ? "Publish EITAN for my Watch" :
                      "Confirm stored EITAN is cleared",
                      systemImage: "icloud.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .tint(HCDesign.electric)
            Text("Private Watch sync does not send EITAN to the AI chat. IsAIah still needs separate permission before any Health data is shared with its online conversation.")
                .font(.system(size: 11))
                .foregroundStyle(HCDesign.secondary)
        }
    }
}

/// A single understandable Health connection surface, rather than a
/// separate metric permission and hidden running importer.
private struct IMUNAppleHealthConnectionCard: View {
    @ObservedObject var appleHealth: HCAppleHealthReader
    @EnvironmentObject private var importer: HCRunHealthImporter
    @AppStorage("hcHealthCatalogEnabled") private var hasRequestedAccess = false
    let compact: Bool

    private var whoopCount: Int {
        importer.workouts.filter {
            $0.source.localizedCaseInsensitiveContains("whoop")
        }.count
    }

    private var firstWorkoutDate: String? {
        importer.workouts.map(\.date).min()
    }

    private func connect() {
        appleHealth.connect(onRequestCompleted: {
            importer.startIfAuthorized()
        })
    }

    private func refresh() {
        appleHealth.refreshIfAuthorized(force: true)
        importer.startIfAuthorized()
    }

    var body: some View {
        HCCard(accent: HCDesign.aqua) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(HCDesign.aqua)
                        .frame(width: 29, height: 29)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apple Health")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(HCDesign.ink)
                        Text(importer.workouts.isEmpty ?
                             (hasRequestedAccess ?
                              (importer.refreshing ? "Checking available records" :
                               "No workout records imported yet") :
                              "Connect your exercise and recovery history") :
                             "Workout history available")
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                    Spacer(minLength: 3)
                    if importer.refreshing || appleHealth.loading {
                        ProgressView().tint(HCDesign.aqua)
                    }
                }

                if !compact || !importer.workouts.isEmpty {
                    HStack(spacing: 8) {
                        HCMetricBlock(label: "Workouts",
                                      value: String(importer.workouts.count))
                        HCMetricBlock(label: "Runs",
                                      value: String(importer.runs.count))
                        HCMetricBlock(label: "WHOOP",
                                      value: String(whoopCount))
                    }
                }

                if !compact {
                    Text("Read workouts, runs, sleep and physiological measurements from the sources Apple Health makes available. Your Garmin and Tredict connection is separate.")
                        .font(.system(size: 12))
                        .foregroundStyle(HCDesign.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let firstWorkoutDate {
                        Text("Earliest imported workout: " + firstWorkoutDate)
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }

                VStack(spacing: 8) {
                    HCFilledButton(
                        title: hasRequestedAccess ? "REVIEW HEALTH ACCESS" :
                               "CONNECT APPLE HEALTH",
                        icon: "heart.fill", tint: HCDesign.aqua,
                        disabled: appleHealth.loading || importer.refreshing) {
                        connect()
                    }
                    if hasRequestedAccess {
                        HCOutlineButton(title: importer.refreshing ?
                                        "Importing workouts…" : "Sync Health data",
                                        icon: "arrow.clockwise") {
                            refresh()
                        }
                    }
                }

                if !compact {
                    Text(importer.status)
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                    Text("Apple may not display the permission sheet again after a decision. To change access, open Health on your iPhone and find iMun under Apps or Data Access & Devices. The counts above reflect imported data—not a claim that every permission was granted.")
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                    Text("IsAIah uses Apple Health readings online only when you enable Health sharing in his chat and send a message.")
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                }
            }
        }
    }
}

private struct IMUNIsaiahMemorySettings: View {
    @AppStorage("hcIsaiahRememberChats") private var rememberChats = true
    @State private var confirmClearMemory = false

    var body: some View {
        HCCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Remember past IsAIah conversations", isOn: $rememberChats)
                    .font(.system(size: 14, weight: .semibold))
                    .tint(HCDesign.electric)
                Text("IsAIah keeps your prior chat messages on this iPhone. When enabled, relevant excerpts are shared with the online coach only after you send a new message. Past chats may contain personal details.")
                    .font(.system(size: 12))
                    .foregroundStyle(HCDesign.secondary)
                Button(role: .destructive) {
                    confirmClearMemory = true
                } label: {
                    Label("Clear remembered conversations", systemImage: "trash")
                }
                .font(.system(size: 12, weight: .medium))
                .confirmationDialog("Clear saved IsAIah memory?",
                                    isPresented: $confirmClearMemory,
                                    titleVisibility: .visible) {
                    Button("Clear remembered conversations", role: .destructive) {
                        IMUNCoachLocalMemory.clear()
                    }
                } message: {
                    Text("This removes the stored long-term chat archive from this iPhone. The visible chat and your workout history are not deleted.")
                }
            }
        }
    }
}

/// Reusable device-location card. New wearables only need a catalog entry.
private struct IMUNWearableLocationCard: View {
    let device: IMUNWearableDefinition
    let selected: IMUNWearableLocation
    let choose: (IMUNWearableLocation) -> Void
    @State private var expanded = false

    var body: some View {
        HCCard {
            VStack(alignment: .leading, spacing: 12) {
                Button { expanded.toggle() } label: {
                    HStack(spacing: 13) {
                        Image(systemName: device.symbol)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(HCDesign.electric)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name.uppercased())
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(HCDesign.ink)
                            Text(selected.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(HCDesign.aqua)
                        }
                        Spacer(minLength: 5)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(HCDesign.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if expanded {
                    Text("WHERE DO YOU WEAR IT?")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(HCDesign.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                              spacing: 8) {
                        ForEach(IMUNWearableLocation.allCases, id: \.rawValue) { choice in
                            Button { choose(choice) } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: selected == choice ?
                                          "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 12))
                                    Text(choice.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: 45,
                                       alignment: .leading)
                                .padding(.horizontal, 10)
                                .foregroundStyle(selected == choice ?
                                    HCDesign.canvas : HCDesign.ink)
                                .background(selected == choice ?
                                    HCDesign.electric : HCDesign.raised,
                                    in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected == choice ? .isSelected : [])
                        }
                    }
                    Text(device.hasSupportedLiveMotion ?
                        "iMun can access this device's live movement sensors. Changing arm position can affect rep-count accuracy." :
                        "Placement saved for future analysis. This device does not currently provide iMun with a supported live gyroscope feed.")
                        .font(.system(size: 11))
                        .foregroundStyle(HCDesign.secondary)
                }
            }
        }
        .onAppear {
            if selected == .unassigned { expanded = true }
        }
    }
}

// All original settings and integrations remain available through the Coach gear.
private struct PremiumSettingsPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @ObservedObject var appleHealth: HCAppleHealthReader
    @AppStorage("hcEitanEnabled") private var eitanEnabled = true
    @AppStorage("hcEitanUseHealth") private var eitanUseHealth = true
    @AppStorage("hcEitanCloudSyncEnabled") private var eitanCloudConsent = false
    @AppStorage("hcEitanCoachingEnabled") private var eitanCoachingEnabled = true
    @AppStorage("hcEitanCoachStyle") private var eitanCoachStyle = "driven"
    @AppStorage("hcEitanPrimaryWearable") private var primaryWearable = "Auto"
    @AppStorage("hcIsaiahRecoveryPriority") private var isaiahRecoveryPriority = "WHOOP"
    @State private var wearableLocations: [String: IMUNWearableLocation] = [:]
    @AppStorage("hcWatchMotionRepEstimate") private var motionAutoReps = true
    @AppStorage("hcWatchMotionRecognitionEnabled") private var learnMovementPatterns = false
    @EnvironmentObject private var tredict: HCTredictImporter
    @State private var tredictToken = ""
    @AppStorage("hcAggressiveProgression") private var aggressive = true
    @AppStorage("hcCoachingNotes") private var notes = ""
    @AppStorage("hcIncludeRecoveryExport") private var includeRecovery = false
    @AppStorage("hcWidgetShareHealth") private var shareWidgetHealth = false
    @AppStorage("hcLiveActivitiesEnabled") private var enableLiveActivities = true
    @AppStorage("hcAccentStyle") private var accentStyle = "crimson"
    @AppStorage("hcDesignPreset") private var designPreset = "techno"
    @AppStorage("hcMotivationSource") private var motivationSource = "off"
    @AppStorage("hcWeightIncrement") private var weightIncrement = 5.0
    @AppStorage("hcRestOverrideSeconds") private var restOverride = 0
    @AppStorage("hcWatchHaptics") private var watchHaptics = true
    @AppStorage("hcRunVoiceCues") private var runVoiceCues = false
    @AppStorage("hcRunAutoLaps") private var runAutoLaps = true
    @AppStorage("hcRunIntervals") private var runIntervals = false
    @AppStorage("hcRunCueMinutes") private var runCueMinutes = 5

    private func loadWearableLocations() {
        IMUNWearablePlacementStore.migrateLegacy()
        wearableLocations = Dictionary(uniqueKeysWithValues:
            IMUNWearableCatalog.devices.map {
                ($0.id, IMUNWearablePlacementStore.location($0.id))
            })
    }

    private func chooseLocation(_ location: IMUNWearableLocation, for id: String) {
        IMUNWearablePlacementStore.save(location, for: id)
        wearableLocations[id] = location
        syncMotionConfiguration()
    }

    private func syncMotionConfiguration() {
        UserDefaults.standard.set(Date().timeIntervalSince1970,
                                  forKey: "hcMotionPreferenceTimestamp")
        coach.sendToWatch()
    }

    private var export: String {
        var lines = ["# IMUN Training Export",
                     "Aggressive progression: \(aggressive)",
                     "## Coach notes", notes, "## Strength"]
        for s in coach.performanceHistory.sorted(by: { $0.date > $1.date }).prefix(250) {
            lines.append("\(s.date): \(s.exercise) · \(s.weightLb.formatted()) lb × \(s.reps) · RIR \(s.rir?.formatted() ?? "—")")
        }
        lines.append("## Running")
        for run in coach.runHistory.prefix(100) {
            let distance = run.distanceMeters.map { String(format: "%.2f mi", $0 / 1609.344) } ?? "—"
            var details = ["\(run.date): \(run.title)", distance, "source: \(run.source)"]
            if let elapsed = run.durationSeconds { details.append("time: \(hcDuration(elapsed))") }
            if let avgHR = run.averageBPM { details.append("avg HR: \(Int(avgHR)) bpm") }
            if let peak = run.maxBPM { details.append("max HR: \(Int(peak)) bpm") }
            if let kcal = run.activeCalories { details.append("active energy: \(Int(kcal)) kcal") }
            if let power = run.averagePowerWatts { details.append("running power: \(Int(power)) W") }
            if let cadence = run.averageCadenceSPM { details.append("cadence: \(Int(cadence)) spm") }
            if let elevation = run.elevationGainMeters { details.append("ascent: \(Int(elevation)) m") }
            if !run.splits.isEmpty {
                details.append("actual lap events: " + run.splits.map {
                    "lap \($0.index) \(hcDuration($0.elapsedSeconds))"
                }.joined(separator: ", "))
            }
            lines.append(details.joined(separator: " · "))
        }
        if includeRecovery {
            lines.append("## Recovery")
            for item in coach.recoveryHistory.prefix(90) {
                lines.append("\(item.date): sleep \(item.sleepSeconds.map(hcDuration) ?? "—"), HRV RMSSD \(item.hrvMS?.formatted() ?? "—") ms, source: \(item.source)")
            }
        }
        return lines.joined(separator: "\n")
    }

    @ViewBuilder
    private var settingsIntro: some View {
                PremiumHeader(eyebrow: "IMUN / SETTINGS",
                              title: "Your preferences.",
                              subtitle: "Fine-tune your coaching, appearance and connections.")
                IMUNAppleHealthConnectionCard(appleHealth: appleHealth,
                                               compact: false)
                HCCard(accent: HCDesign.electric) {
                    VStack(alignment: .leading, spacing: 11) {
                        HCAccentTag(title: "TRAINING INTELLIGENCE")
                        Toggle(isOn: $aggressive) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Smart aggressive progression").font(.headline)
                                Text("Add reps first; increase load when earned.")
                                    .font(.caption)
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                        .tint(HCDesign.electric)
                        Text("Movement changes use conservative estimates, confidence labels, and your subsequent actual performance.")
                            .font(.caption2).foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "Wearable placement",
                               detail: "Which arm and where each device sits")
                HCCard {
                    VStack(alignment: .leading, spacing: 11) {
                        Toggle("Automatic rep counting", isOn: $motionAutoReps)
                            .tint(HCDesign.electric)
                            .onChange(of: motionAutoReps) { _, _ in
                                syncMotionConfiguration()
                            }
                        Toggle("Learn exercise motion patterns",
                               isOn: $learnMovementPatterns)
                            .tint(HCDesign.electric)
                            .onChange(of: learnMovementPatterns) { _, _ in
                                syncMotionConfiguration()
                            }
                        Text("For arm-specific sets, iMun uses the selected device's side. Wrist, forearm and biceps positions are recorded separately so the motion model can be calibrated accurately.")
                            .font(.caption)
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                ForEach(IMUNWearableCatalog.devices) { device in
                    IMUNWearableLocationCard(
                        device: device,
                        selected: wearableLocations[device.id] ??
                            IMUNWearablePlacementStore.location(device.id)
                    ) { place in
                        chooseLocation(place, for: device.id)
                    }
                }
                Text("Apple Watch supplies live Core Motion. WHOOP placement is saved, but its official API does not provide live raw motion. Other wearable models can be added to this device list in future releases.")
                    .font(.caption2)
                    .foregroundStyle(HCDesign.secondary)
    }

    @ViewBuilder
    private var settingsIntelligence: some View {
                HCSectionTitle(title: "IsAIah sources", detail: "Your recovery, across devices")
                HCCard {
                    VStack(alignment: .leading, spacing: 11) {
                        Picker("Preferred recovery source", selection: $isaiahRecoveryPriority) {
                            Text("WHOOP first").tag("WHOOP")
                            Text("Garmin first").tag("Garmin")
                            Text("Apple Watch first").tag("Apple Watch")
                            Text("All sources, labeled").tag("Auto")
                        }
                        .tint(HCDesign.electric)
                        Text("This prioritizes the source IsAIah discusses first—not the only data he can read. WHOOP, Apple Watch, Garmin and Tredict remain separate in long-term comparisons. Missing workouts are unknown, not rest days.")
                            .font(.system(size: 12))
                            .foregroundStyle(HCDesign.secondary)
                        Text("EITAN has a separate primary-wearable setting below for its daily wellness score.")
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                HCSectionTitle(title: "IsAIah memory", detail: "Conversation continuity")
                IMUNIsaiahMemorySettings()
                HCSectionTitle(title: "EITAN", detail: "Wellness & adaptive coaching")
                HCCard {
                    VStack(alignment: .leading, spacing: 13) {
                        Toggle(isOn: $eitanEnabled) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Show EITAN").font(.system(size: 14, weight: .semibold))
                                Text("Display the EITAN score and its explanation on Apple Watch and Today.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                        .tint(HCDesign.electric)
                        if eitanEnabled {
                            Divider()
                            HCEitanPrimaryWearableSelector(
                                primaryWearable: $primaryWearable)
                            Divider()
                            Toggle(isOn: $eitanUseHealth) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Use Health data for EITAN")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("On: personal wellness trends from authorized measurements. Off: training momentum only; no Health readings enter EITAN.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(HCDesign.secondary)
                                }
                            }
                            .tint(HCDesign.electric)
                            Divider()
                            Toggle(isOn: $eitanCoachingEnabled) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Adaptive IsAIah suggestions")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Challenge when appropriate, adapt by RIR and effort, and discuss recovery after accumulating strain. No automatic workout edits.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(HCDesign.secondary)
                                }
                            }
                            .tint(HCDesign.electric)
                            if eitanCoachingEnabled {
                                Picker("IsAIah coaching approach", selection: $eitanCoachStyle) {
                                    Text("Driven").tag("driven")
                                    Text("Balanced").tag("balanced")
                                    Text("Recovery-first").tag("cautious")
                                }
                                .tint(HCDesign.electric)
                                Text("Style changes coaching tone, not the safety signals or your control of workout edits.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            HCEitanCloudSyncControls(consent: $eitanCloudConsent)
                            Divider()
                            Text(coach.watchConnectionDetails)
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("EITAN transfer · " + coach.eitanWatchSyncStatus)
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Background queue · " + coach.lastBackgroundTransfer)
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Phone build " +
                                 (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))
                                .font(.system(size: 10))
                                .foregroundStyle(HCDesign.secondary)
                            Button {
                                coach.sendEitanToWatch(forceQueue: true)
                            } label: {
                                Label("Sync EITAN to Apple Watch",
                                      systemImage: "applewatch.radiowaves.left.and.right")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                            .tint(HCDesign.electric)
                        }
                    }
                }
    }

    @ViewBuilder
    private var settingsIdentity: some View {
                HCSectionTitle(title: "Home & Lock Screen", detail: "Widgets and live workouts")
                HCCard {
                    VStack(alignment: .leading, spacing: 13) {
                        Toggle(isOn: $enableLiveActivities) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Live workout activity")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Show active workout and rest timer on the Lock Screen and Dynamic Island.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                        .tint(HCDesign.electric)
                        Divider()
                        Toggle(isOn: $shareWidgetHealth) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Show health data in widgets")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Opt in to show source-labeled sleep and HRV on the Home Screen widget. Off by default.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                        .tint(HCDesign.electric)
                        Text("Add iMun Today from iPhone's widget gallery. Tap the widget to open Today.")
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                                HCSectionTitle(title: "Identity", detail: "Your look & your mindset")
                NavigationLink {
                    IMUNDesignStudioPage()
                } label: {
                    HCCard(accent: HCDesign.electric) {
                        HStack(spacing: 14) {
                            Image(systemName: IMUNStyle.preset.symbol)
                                .font(.system(size: 25, weight: .light))
                                .foregroundStyle(HCDesign.electric)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DESIGN STUDIO")
                                    .font(HCDesign.label(12)).tracking(1.2)
                                    .foregroundStyle(HCDesign.ink)
                                Text(IMUNStyle.preset.title + " · " +
                                     IMUNStyle.preset.tagline)
                                    .font(.caption)
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                NavigationLink {
                    IMUNMotivationPage()
                } label: {
                    HCCard {
                        HStack(spacing: 14) {
                            Image(systemName: "bookmark")
                                .font(.title2)
                                .foregroundStyle(HCDesign.aqua)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MOTIVATION & SCRIPTURE")
                                    .font(HCDesign.label(12)).tracking(1)
                                    .foregroundStyle(HCDesign.ink)
                                Text(motivationSource == "off" ?
                                     "Off by default · choose your own content" :
                                     "Your selected content is enabled")
                                    .font(.caption)
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
    }

    @ViewBuilder
    private var settingsWorkoutControls: some View {
                HCSectionTitle(title: "Workout controls")
                HCCard {
                    VStack(alignment: .leading, spacing: 15) {
                        Picker("Weight step", selection: $weightIncrement) {
                            Text("2.5 lb").tag(2.5)
                            Text("5 lb").tag(5.0)
                            Text("10 lb").tag(10.0)
                        }
                        .tint(HCDesign.electric)
                        Divider().overlay(HCDesign.outline)
                        Picker("Rest after a set", selection: $restOverride) {
                            Text("Use workout plan").tag(0)
                            Text("60 sec").tag(60)
                            Text("90 sec").tag(90)
                            Text("2 min").tag(120)
                            Text("3 min").tag(180)
                        }
                        .tint(HCDesign.electric)
                        Divider().overlay(HCDesign.outline)
                        Toggle("Haptic alerts on the Watch", isOn: $watchHaptics)
                            .tint(HCDesign.electric)
                        Text("Changes are saved automatically and sent to your Watch when paired.")
                            .font(.caption2).foregroundStyle(HCDesign.secondary)
                    }
                }
                .onChange(of: weightIncrement) { _, _ in coach.sendToWatch() }
                .onChange(of: restOverride) { _, _ in coach.sendToWatch() }
                .onChange(of: watchHaptics) { _, _ in coach.sendToWatch() }
                HCSectionTitle(title: "Run coaching & auto laps")
                HCCard(accent: HCDesign.aqua) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Spoken cues through Watch audio", isOn: $runVoiceCues)
                            .tint(HCDesign.aqua)
                        Divider().overlay(HCDesign.outline)
                        Toggle("Automatic mile laps & split announcements", isOn: $runAutoLaps)
                            .tint(HCDesign.aqua)
                        Divider().overlay(HCDesign.outline)
                        Toggle("Timed interval coaching", isOn: $runIntervals)
                            .tint(HCDesign.aqua)
                        if runIntervals {
                            HCStatusLine(text: "5-min warm-up · 5 × (3-min effort / 2-min recovery) · cool-down",
                                         symbol: "timer", tint: HCDesign.aqua)
                        }
                        Picker("Spoken pace & HR updates", selection: $runCueMinutes) {
                            Text("Off").tag(0)
                            Text("Every minute").tag(1)
                            Text("Every 2 min").tag(2)
                            Text("Every 5 min").tag(5)
                            Text("Every 10 min").tag(10)
                        }
                        .tint(HCDesign.aqua)
                        Text("Audio plays from the Apple Watch recording the run. Pair your headphones with that Watch. GPS/HealthKit data and watchOS playback availability determine which cues can be spoken. Haptics remain available when audio cannot play.")
                            .font(.caption2).foregroundStyle(HCDesign.secondary)
                    }
                }
                .onChange(of: runVoiceCues) { _, _ in coach.sendToWatch() }
                .onChange(of: runAutoLaps) { _, _ in coach.sendToWatch() }
                .onChange(of: runIntervals) { _, _ in coach.sendToWatch() }
                .onChange(of: runCueMinutes) { _, _ in coach.sendToWatch() }
    }

    @ViewBuilder
    private var settingsSharing: some View {
                HCSectionTitle(title: "Your coaching notes")
                HCCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Soreness, schedule changes, substitutions, goals...")
                            .font(.caption).foregroundStyle(HCDesign.secondary)
                        TextEditor(text: $notes)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .padding(6)
                            .background(HCDesign.raised, in: RoundedRectangle(cornerRadius: 13))
                    }
                }
                HCSectionTitle(title: "AI export & sharing")
                HCCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("Include recovery measurements", isOn: $includeRecovery)
                            .tint(HCDesign.electric)
                        ShareLink(item: export) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("EXPORT TRAINING FOR AI")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(HCDesign.onAccent)
                            .padding(16)
                            .background(HCDesign.electric, in: RoundedRectangle(cornerRadius: 14))
                        }
                        Text("Only you decide whether and where to share this export.")
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
    }

    @ViewBuilder
    private var settingsTredict: some View {
                HCSectionTitle(title: "Tredict / Garmin", detail: "Full-history personal connection")
                HCCard {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            Image(systemName: "waveform.path")
                                .foregroundStyle(HCDesign.electric)
                            Text(tredict.connected ? "Tredict connection saved" :
                                 "Connect your Tredict account")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Text("Use a read-only Personal API token from Tredict → Settings → Personal API. Choose activityRead and bodyvaluesRead. The token stays in your iPhone Keychain; training data is downloaded to this device.")
                            .font(.caption)
                            .foregroundStyle(HCDesign.secondary)
                        if !tredict.connected {
                            SecureField("Personal API token", text: $tredictToken)
                                .textContentType(.password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(HCDesign.raised,
                                            in: RoundedRectangle(cornerRadius: 12))
                            HCFilledButton(title: "CONNECT & IMPORT HISTORY",
                                           icon: "arrow.down.circle.fill",
                                           disabled: tredictToken.isEmpty || tredict.loading) {
                                tredict.connect(token: tredictToken)
                                tredictToken = ""
                            }
                        } else {
                            HCFilledButton(title: tredict.loading ? "IMPORTING HISTORY…" :
                                                "SYNC ALL TREDICT HISTORY",
                                           icon: "arrow.clockwise",
                                           disabled: tredict.loading) {
                                tredict.refresh()
                            }
                            HCOutlineButton(title: "Disconnect Tredict", icon: "xmark.circle") {
                                tredict.disconnect()
                            }
                        }
                        if tredict.loading { ProgressView().tint(HCDesign.electric) }
                        Text(tredict.status)
                            .font(.caption)
                            .foregroundStyle(HCDesign.secondary)
                        if tredict.snapshot.lastSync != nil {
                            Text("Imported \(tredict.snapshot.rawActivityCount) activities · " +
                                 "\(tredict.snapshot.recovery.count) recovery days")
                                .font(.system(size: 12, weight: .medium))
                            Text("Included: " + tredict.snapshot.dataTypes.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(HCDesign.secondary)
                        }
                        if let archive = tredict.archiveURL {
                            ShareLink(item: archive) {
                                Label("Export original Tredict data archive",
                                      systemImage: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HCDesign.electric)
                            }
                        }
                        Link(destination: URL(string: "https://www.tredict.com/faq/personal-api---connect-your-own-scripts-or-personal-applications/")!) {
                            Label("How to create a Tredict API token",
                                  systemImage: "arrow.up.right")
                                .font(.system(size: 12))
                        }
                    }
                }
    }

    @ViewBuilder
    private var settingsHistory: some View {
                HCSectionTitle(title: "Connected training history")
                HCCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("IMPORTED ACTIVITY SOURCES")
                            .font(HCDesign.label(10))
                            .foregroundStyle(HCDesign.secondary)
                        ForEach(
                            Array(Dictionary(grouping: coach.trainingActivities,
                                            by: { IMUNDataProvenance.provider($0.source) })
                                .keys).sorted(), id: \.self) { provider in
                            let rows = coach.trainingActivities.filter {
                                IMUNDataProvenance.provider($0.source) == provider
                            }
                            HStack {
                                Text(provider)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Text("\(rows.count) sessions")
                                    .font(.system(size: 12))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                        }
                        Text("A missing day from any device is unknown. Imported record counts may exclude workouts kept only inside WHOOP or Garmin Connect.")
                            .font(.system(size: 11))
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
                HCCard {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack(spacing: 8) {
                            HCMetricBlock(label: "Working sets",
                                          value: String(coach.performanceHistory.count))
                            HCMetricBlock(label: "Past sessions",
                                          value: String(coach.trainingActivities.count))
                        }
                        HStack(spacing: 8) {
                            HCMetricBlock(label: "Run records",
                                          value: String(coach.runHistory.count))
                            HCMetricBlock(label: "Recovery days",
                                          value: String(coach.recoveryHistory.count))
                        }
                        Text("IMUN uses the original Health Coach and Tredict records stored in your Command Center account. Recording sources are preserved; activity and recovery metrics are not combined into made-up values.")
                            .font(.caption)
                            .foregroundStyle(HCDesign.secondary)
                        HCOutlineButton(title: "Refresh all connected data",
                                        icon: "arrow.clockwise") {
                            coach.refresh(date: Date())
                        }
                        if let archive = coach.legacyArchiveURL {
                            ShareLink(item: archive) {
                                Label("Export original source archive",
                                      systemImage: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HCDesign.electric)
                                    .padding(.vertical, 6)
                            }
                            Text("Contains your full legacy planner and training state, plus available workout and recovery records. Sharing is your choice.")
                                .font(.caption2)
                                .foregroundStyle(HCDesign.secondary)
                        }
                        Link(destination: URL(string: "https://www.tredict.com/faq/garmin-connect---how-to-connect-and-synchronize-my-device/")!) {
                            Label("Tredict Garmin history import instructions",
                                  systemImage: "arrow.up.right")
                                .font(.system(size: 12, weight: .medium))
                        }
                        Text("Additional Garmin sessions must first be made available through Tredict and your Command Center integration. IMUN cannot read a separate Garmin or Tredict account without that connection.")
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
    }

    @ViewBuilder
    private var settingsConnections: some View {
                HCSectionTitle(title: "Connections")
                HCCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HCSyncStatus(pending: coach.cloudPendingCount,
                                     saving: coach.savingPlan, connected: coach.signedIn)
                        Text(coach.status)
                            .font(.caption).foregroundStyle(HCDesign.secondary)
                        HCOutlineButton(title: "Retry all uploads", icon: "arrow.clockwise") {
                            coach.retryPendingWorkout()
                            coach.retryPendingCloudSets()
                        }
                        HCOutlineButton(title: "Refresh & send workout to Watch",
                                        icon: "applewatch") {
                            coach.refreshAndSendToWatch()
                        }
                        HCOutlineButton(title: "Check Watch connection",
                                        icon: "antenna.radiowaves.left.and.right") {
                            coach.checkWatchConnection()
                        }
                        Text(coach.watchConnectionDetails)
                            .font(.caption2)
                            .foregroundStyle(HCDesign.aqua)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(coach.watchSyncStatus)
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(coach.cloudWorkoutStatus)
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Apple Health · " + appleHealth.status)
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Background Watch transfers · " + coach.lastBackgroundTransfer)
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let confirmed = coach.watchLastAcknowledgedAt {
                            Text("Watch confirmed receipt " +
                                 confirmed.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(HCDesign.good)
                        }
                        if !coach.signedIn {
                            PremiumLogin()
                        } else {
                            HCOutlineButton(title: "Sign out", icon: "rectangle.portrait.and.arrow.right") {
                                coach.logout()
                            }
                        }
                    }
                }
                HStack {
                    Image(systemName: "checkmark.seal")
                        .foregroundStyle(HCDesign.aqua)
                    Text("imun " +
                         (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") +
                         " · build " +
                         (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))
                        .font(.caption2)
                        .foregroundStyle(HCDesign.secondary)
                    Spacer()
                }
                .padding(.top, 7)
                Spacer(minLength: 30)
    }


    var body: some View {
        ScrollView {
            // Settings sections render on demand, matching Progress/Health.
            LazyVStack(alignment: .leading, spacing: 19) {
                settingsIntro
                settingsIntelligence
                settingsIdentity
                settingsWorkoutControls
                settingsSharing
                settingsTredict
                settingsHistory
                settingsConnections
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .hcPage()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Settings")
        .onAppear { loadWearableLocations() }
    }
    @ViewBuilder
    private func accentTile(id: String, name: String, tint: Color) -> some View {
        Button {
            accentStyle = id
            coach.sendToWatch()
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(HCDesign.raised)
                    Circle().fill(tint)
                        .frame(width: 23, height: 23)
                    if accentStyle == id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(id == "crimson" ? .white : HCDesign.canvas)
                    }
                }
                .frame(height: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(accentStyle == id ? tint : HCDesign.outline,
                                      lineWidth: accentStyle == id ? 2 : 1)
                }
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(HCDesign.ink)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name + " accent color")
        .accessibilityAddTraits(accentStyle == id ? [.isSelected] : [])
    }

}
