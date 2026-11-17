import SwiftUI
import UIKit

/// Personal control center for the entire IMUN visual language. All changes
/// are local preferences; workout history, account data and health permissions
/// are never modified by this screen.
struct IMUNDesignStudioPage: View {
    @EnvironmentObject private var coach: PhoneWorkoutBridge
    @AppStorage("hcDesignPreset") private var preset = "techno"
    @AppStorage("hcDesignMode") private var mode = "dark"
    @AppStorage("hcDesignCustomPalette") private var customPalette = false
    @AppStorage("hcDesignCustomGeometry") private var customGeometry = false
    @AppStorage("hcDesignAccentHex") private var accentHex = "D4324F"
    @AppStorage("hcDesignBackgroundHex") private var backgroundHex = "070C16"
    @AppStorage("hcDesignSurfaceHex") private var surfaceHex = "212831"
    @AppStorage("hcDesignTextHex") private var textHex = "F6F3E9"
    @AppStorage("hcDesignShape") private var shape = "rounded"
    @AppStorage("hcDesignButtonShape") private var buttonShape = "rounded"
    @AppStorage("hcDesignFont") private var headingFont = "standard"
    @AppStorage("hcDesignDensity") private var density = "balanced"
    @AppStorage("hcDesignMotif") private var motif = "none"
    @AppStorage("hcDesignNavigation") private var navigation = "standard"
    @AppStorage("hcDesignProgress") private var progress = "ring"
    @AppStorage("hcDesignReduceMotion") private var reduceMotion = false
    @AppStorage("hcDesignWatchSyncEnabled") private var shareWithWatch = false

    // Debounce ColorPicker drags and layout changes. Every published version
    // is a tiny preferences-only snapshot, never a workout transfer.
    private var designSignature: String {
        [preset, mode, String(customPalette), String(customGeometry),
         accentHex, backgroundHex, surfaceHex, textHex, shape,
         buttonShape, headingFont, density, motif, navigation,
         progress, String(reduceMotion), String(shareWithWatch),
         String(coach.signedIn)]
            .joined(separator: "|")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                VStack(alignment: .leading, spacing: 8) {
                    HCAccentTag(title: "IMUN / DESIGN LAB")
                    Text("Make it yours.")
                        .font(HCDesign.display(38))
                        .foregroundStyle(HCDesign.ink)
                    Text("Eight distinct visual identities. One training system. Fine-tune every detail without changing your workouts.")
                        .font(.subheadline)
                        .foregroundStyle(HCDesign.secondary)
                }

                HCSectionTitle(title: "Live previews", detail: "Unique to each theme")
                Text("Preview graphics are examples; your actual completed-set counts come from training history.")
                    .font(.caption2)
                    .foregroundStyle(HCDesign.secondary)
                previews

                HCCard {
                    VStack(alignment: .leading, spacing: 11) {
                        IMUNThemeEmblem(area: "training")
                        IMUNThemeTimerFace(seconds: 75, countsDown: true)
                        Text("Live style sample · 1:15 rest timer. No training clock is running.")
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                }

                HCSectionTitle(title: "Choose an identity", detail: "Tap a preset")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(IMUNPreset.allCases) { option in
                        presetCard(option)
                    }
                }

                HCSectionTitle(title: "Lighting")
                HCCard {
                    Picker("Appearance", selection: $mode) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("System").tag("system")
                    }
                    .pickerStyle(.segmented)
                    Text("Watch uses its dark, high-contrast interface. System mode follows iPhone appearance.")
                        .font(.caption2)
                        .foregroundStyle(HCDesign.secondary)
                }

                HCSectionTitle(title: "Custom palette")
                HCCard {
                    Toggle("Override preset colors", isOn: $customPalette)
                        .tint(HCDesign.electric)
                    if customPalette {
                        colorRow("Accent", hex: $accentHex)
                        colorRow("Background", hex: $backgroundHex)
                        colorRow("Card surfaces", hex: $surfaceHex)
                        colorRow("Text", hex: $textHex)
                        Button("Start from current preset colors") {
                            let p = IMUNStyle.preset
                            accentHex = p.accent
                            backgroundHex = p.darkBackground
                            surfaceHex = p.darkBackground
                            textHex = "F6F3E9"
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HCDesign.electric)
                        Text("Maintain strong contrast between your text, surfaces and accent. A live preview updates as you make changes.")
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                }

                HCSectionTitle(title: "Motivation", detail: "Independent of your theme")
                NavigationLink {
                    IMUNMotivationPage()
                } label: {
                    HCCard {
                        HStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.title2)
                                .foregroundStyle(HCDesign.aqua)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("WORDS TO TRAIN BY")
                                    .font(HCDesign.label(12)).tracking(1)
                                    .foregroundStyle(HCDesign.ink)
                                Text("Off, original writing, performance, Scripture references, or your own.")
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

                HCSectionTitle(title: "Layout & typography")
                HCCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Customize layout beyond the preset", isOn: $customGeometry)
                            .tint(HCDesign.electric)
                        if customGeometry {
                            Picker("Card silhouette", selection: $shape) {
                                Text("Rounded").tag("rounded")
                                Text("Square").tag("square")
                                Text("Chamfered").tag("chamfered")
                                Text("Pill").tag("pill")
                                Text("Asymmetric").tag("asymmetric")
                            }
                            Picker("Button silhouette", selection: $buttonShape) {
                                Text("Rounded").tag("rounded")
                                Text("Square").tag("square")
                                Text("Chamfered").tag("chamfered")
                                Text("Pill").tag("pill")
                                Text("Asymmetric").tag("asymmetric")
                            }
                            Picker("Heading type", selection: $headingFont) {
                                Text("Classic serif").tag("serif")
                                Text("Clean sans").tag("standard")
                                Text("Soft rounded").tag("rounded")
                                Text("Technical mono").tag("monospaced")
                            }
                            Picker("Space", selection: $density) {
                                Text("Compact").tag("compact")
                                Text("Balanced").tag("balanced")
                                Text("Airy").tag("airy")
                            }
                            Picker("Background motif", selection: $motif) {
                                Text("None").tag("none")
                                Text("Keylines").tag("keylines")
                                Text("Contour").tag("contours")
                                Text("Grid").tag("grid")
                                Text("Stripes").tag("stripes")
                                Text("Ambient glow").tag("glow")
                            }
                            Picker("Navigation personality", selection: $navigation) {
                                Text("Classic").tag("standard")
                                Text("Editorial").tag("editorial")
                                Text("Sport").tag("sport")
                            }
                            Picker("Progress indicator", selection: $progress) {
                                Text("Circular").tag("ring")
                                Text("Segmented").tag("segmented")
                            }
                        } else {
                            Text("Using the selected preset's silhouettes, typography, spacing and visual motifs.")
                                .font(.caption)
                                .foregroundStyle(HCDesign.secondary)
                        }
                        Toggle("Reduce decorative motion", isOn: $reduceMotion)
                            .tint(HCDesign.electric)
                    }
                }

                HCCard(accent: HCDesign.electric) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("YOUR WATCH")
                            .font(HCDesign.label(11)).tracking(1.3)
                            .foregroundStyle(HCDesign.electric)
                        Text("The Watch can use the same visual identity or its own selection.")
                            .font(.caption)
                            .foregroundStyle(HCDesign.secondary)
                        Toggle("Sync this appearance to my Watch", isOn: $shareWithWatch)
                            .tint(HCDesign.electric)
                        HCFilledButton(title: "SYNC DESIGN THROUGH CLOUD",
                                       icon: "icloud.and.arrow.up",
                                       disabled: !coach.signedIn) {
                            coach.publishDesignToCloud()
                        }
                        Text(coach.designCloudStatus)
                            .font(.caption)
                            .foregroundStyle(HCDesign.secondary)
                        Text("Appearance sync uses your private iMun account, independently of the iPhone–Watch link. Open Watch → Preferences to fetch it, or disable 'Use iPhone style' to choose a different Watch theme.")
                            .font(.caption2)
                            .foregroundStyle(HCDesign.secondary)
                    }
                }
            }
            .padding(18)
        }
        .hcPage()
        .navigationTitle("Design studio")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: designSignature) {
            guard coach.signedIn else { return }
            // Turning sharing off is itself a cloud update, so Watch stops
            // applying future iPhone changes.
            do {
                try await Task.sleep(nanoseconds: 850_000_000)
            } catch { return }
            coach.publishDesignToCloud()
        }
    }

    private func colorRow(_ title: String, hex: Binding<String>) -> some View {
        ColorPicker(title, selection: Binding(
            get: { IMUNStyle.resolvedColor(hex.wrappedValue) },
            set: { value in
                let color = UIColor(value)
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return }
                hex.wrappedValue = String(format: "%02X%02X%02X",
                    Int(red*255),Int(green*255),Int(blue*255))
            }
        ))
        .tint(HCDesign.electric)
    }

    private var previews: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(alignment: .leading, spacing: 14) {
                Text("IPHONE / TRAINING")
                    .font(HCDesign.label(9)).tracking(1.5)
                    .foregroundStyle(HCDesign.electric)
                Text("Push — Strength")
                    .font(HCDesign.display(20))
                    .foregroundStyle(HCDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("PREPARED • 8 MOVEMENTS")
                    .font(HCDesign.label(9))
                    .foregroundStyle(HCDesign.secondary)
                HStack(spacing: 5) {
                    Image(systemName: "dumbbell.fill")
                    Text("START SESSION")
                }
                .font(HCDesign.label(11))
                .foregroundStyle(HCDesign.onAccent)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(HCDesign.electric,
                            in: IMUNPanelShape(shape: IMUNStyle.buttonShape, corner: 13))
            }
            .padding(IMUNStyle.padding)
            .frame(maxWidth: .infinity, minHeight: 208, alignment: .topLeading)
            .background(HCDesign.card, in: IMUNPanelShape())
            .overlay(IMUNPanelShape().stroke(HCDesign.outline, lineWidth: 1))

            VStack(alignment: .center, spacing: 8) {
                Text("WATCH / PREVIEW")
                    .font(HCDesign.label(9)).tracking(1)
                    .foregroundStyle(HCDesign.electric)
                IMUNThemeProgressView(completed: 3, planned: 5, compact: true)
                Text(IMUNStyle.preset.title.uppercased())
                    .font(HCDesign.label(10))
                    .foregroundStyle(HCDesign.ink)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text("Example 3/5 sets")
                    .font(.system(size: 9))
                    .foregroundStyle(HCDesign.secondary)
            }
            .padding(12)
            .frame(width: 127, height: 208)
            .background(HCDesign.canvas,
                        in: RoundedRectangle(cornerRadius: 35))
            .overlay(RoundedRectangle(cornerRadius: 35)
                        .stroke(HCDesign.electric.opacity(0.55), lineWidth: 2))
            .accessibilityLabel("Apple Watch theme preview")
        }
    }

    private func presetCard(_ option: IMUNPreset) -> some View {
        let selected = option.rawValue == preset
        return Button {
            preset = option.rawValue
            // Presets update all system tokens. Custom overrides remain
            // available, but reset automatically when selecting a new style.
            customPalette = false
            customGeometry = false
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: option.symbol)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(IMUNStyle.resolvedColor(option.accent))
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(HCDesign.electric)
                    }
                }
                HStack(spacing: 5) {
                    Circle().fill(IMUNStyle.resolvedColor(option.darkBackground))
                    Circle().fill(IMUNStyle.resolvedColor(option.accent))
                    Circle().fill(IMUNStyle.resolvedColor(option.accentTwo))
                }
                .frame(height: 14)
                Text(option.title)
                    .font(.system(size: 17, weight: .semibold,
                                  design: option.defaultFont == "serif" ? .serif : .rounded))
                    .foregroundStyle(HCDesign.ink)
                Text(option.tagline)
                    .font(.system(size: 11))
                    .foregroundStyle(HCDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
            .padding(15)
            .background(HCDesign.card,
                        in: IMUNPanelShape(shape: option.defaultShape, corner: 16))
            .overlay(IMUNPanelShape(shape: option.defaultShape, corner: 16)
                     .stroke(selected ? HCDesign.electric : HCDesign.outline,
                             lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title + " preset " +
                            (selected ? "selected" : "available"))
    }
}

/// Local-only records. No journals, saved notes or user-authored text are
/// uploaded to the theme cloud table or sent in workout sync payloads.
private struct IMUNMindsetEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let savedAt: Date
    let kind: String // "saved" daily line or "journal" athlete-authored writing
}

/// Motivation is opt-in, user-authored content is entirely local, and ESV/LSB
/// references are shown instead of embedding copyrighted translation text.
struct IMUNMotivationPage: View {
    @AppStorage("hcMotivationSource") private var source = "off"
    @AppStorage("hcMotivationTranslation") private var translation = "ESV"
    @AppStorage("hcMotivationTone") private var tone = "quiet"
    @AppStorage("hcMotivationCustom") private var custom = ""
    @AppStorage("hcMotivationFavorite") private var favorite = "" // Legacy single favorite
    @AppStorage("hcMotivationEntriesV1") private var archive = ""
    @AppStorage("hcMotivationShowTraining") private var showOnTraining = false
    @State private var journalDraft = ""

    private var entries: [IMUNMindsetEntry] {
        guard let data = archive.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([IMUNMindsetEntry].self, from: data)
        else { return [] }
        return decoded.sorted { $0.savedAt > $1.savedAt }
    }

    private var currentIsSaved: Bool {
        guard let line = IMUNMotivation.line else { return false }
        return entries.contains { $0.kind == "saved" && $0.text == line }
    }

    @discardableResult
    private func updateEntries(_ updated: [IMUNMindsetEntry]) -> Bool {
        let limited = Array(updated.sorted { $0.savedAt > $1.savedAt }.prefix(120))
        guard let data = try? JSONEncoder().encode(limited),
              let text = String(data: data, encoding: .utf8) else { return false }
        archive = text
        return archive == text
    }

    private func saveCurrentNote() {
        guard let line = IMUNMotivation.line, !currentIsSaved else { return }
        updateEntries(entries + [IMUNMindsetEntry(
            id: UUID(), text: String(line.prefix(1000)),
            savedAt: Date(), kind: "saved")])
    }

    private func saveJournalEntry() {
        let content = journalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        if updateEntries(entries + [IMUNMindsetEntry(
            id: UUID(), text: String(content.prefix(1000)),
            savedAt: Date(), kind: "journal")]) {
            journalDraft = ""
        }
    }

    private func removeEntry(_ id: UUID) {
        updateEntries(entries.filter { $0.id != id })
    }

    private func importLegacyFavorite() {
        let old = favorite.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !old.isEmpty else { return }
        if !entries.contains(where: { $0.kind == "saved" && $0.text == old }) {
            guard updateEntries(entries + [IMUNMindsetEntry(
                id: UUID(), text: old, savedAt: Date(), kind: "saved")])
            else { return }
        }
        favorite = ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                HCAccentTag(title: "IMUN / MINDSET")
                Text("The work behind the work.")
                    .font(HCDesign.display(34))
                    .foregroundStyle(HCDesign.ink)
                Text("Decide what, if anything, motivates you. This is separate from your visual theme.")
                    .font(.subheadline)
                    .foregroundStyle(HCDesign.secondary)
                HCCard(accent: HCDesign.electric) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("DAILY NOTE")
                            .font(HCDesign.label(11)).tracking(2)
                            .foregroundStyle(HCDesign.electric)
                        if let line = IMUNMotivation.line {
                            Text(line)
                                .font(HCDesign.display(24))
                                .foregroundStyle(HCDesign.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if source == "scripture" {
                                Text("Scripture reference only. Read the passage in your preferred ESV or LSB Bible.")
                                    .font(.caption)
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            Button(action: saveCurrentNote) {
                                Label(currentIsSaved ? "Saved to your collection" : "Save this note",
                                      systemImage: currentIsSaved ? "bookmark.fill" : "bookmark")
                            }
                            .disabled(currentIsSaved)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HCDesign.electric)
                        } else {
                            Text("Motivation is turned off.")
                                .font(HCDesign.display(22))
                                .foregroundStyle(HCDesign.ink)
                            Text("Your training screens stay focused without additional quotes or prompts.")
                                .font(.caption)
                                .foregroundStyle(HCDesign.secondary)
                        }
                    }
                }
                HCSectionTitle(title: "In your training day")
                HCCard {
                    Toggle("Show today's note on Training", isOn: $showOnTraining)
                        .tint(HCDesign.electric)
                    Text("Off by default. Notes appear only when you've selected a content source. This does not change your theme or your workout.")
                        .font(.caption2)
                        .foregroundStyle(HCDesign.secondary)
                }
                HCSectionTitle(title: "Personal training journal")
                HCCard {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("Keep a private thought, lesson, or intention from today's training.")
                            .font(.caption)
                            .foregroundStyle(HCDesign.secondary)
                        TextField("What mattered in today's work?",
                                  text: $journalDraft, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Text("\(journalDraft.count)/1000")
                                .font(.caption2)
                                .foregroundStyle(HCDesign.secondary)
                            Spacer()
                            Button {
                                saveJournalEntry()
                            } label: {
                                Label("Save journal entry", systemImage: "square.and.pencil")
                            }
                            .disabled(journalDraft.trimmingCharacters(
                                in: .whitespacesAndNewlines).isEmpty ||
                                journalDraft.count > 1000)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HCDesign.electric)
                        }
                    }
                }
                if !entries.isEmpty {
                    HCSectionTitle(title: "Saved notes & journal",
                                   detail: "\(entries.count) private entries")
                    ForEach(entries) { entry in
                        HCCard {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    Label(entry.kind == "journal" ? "JOURNAL" : "SAVED NOTE",
                                          systemImage: entry.kind == "journal" ?
                                            "square.and.pencil" : "bookmark.fill")
                                        .font(HCDesign.label(10))
                                        .foregroundStyle(HCDesign.aqua)
                                    Spacer()
                                    Text(entry.savedAt.formatted(
                                        date: .abbreviated, time: .omitted))
                                        .font(.caption2)
                                        .foregroundStyle(HCDesign.secondary)
                                }
                                Text(entry.text)
                                    .font(.system(size: 14, weight: .medium,
                                                  design: IMUNStyle.headingDesign))
                                    .foregroundStyle(HCDesign.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button(role: .destructive) {
                                    removeEntry(entry.id)
                                } label: {
                                    Label("Remove entry", systemImage: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                HCSectionTitle(title: "Content source")
                HCCard {
                    Picker("Show motivation", selection: $source) {
                        Text("Off").tag("off")
                        Text("Original writing").tag("original")
                        Text("Performance").tag("performance")
                        Text("Scripture references").tag("scripture")
                        Text("My own words").tag("custom")
                    }
                    .pickerStyle(.inline)
                    if source == "scripture" {
                        Picker("Translation preference", selection: $translation) {
                            Text("ESV").tag("ESV")
                            Text("LSB").tag("LSB")
                        }
                        .pickerStyle(.segmented)
                        Text("Translations are not embedded or fetched without permission. References can be opened in your Bible app.")
                            .font(.caption2).foregroundStyle(HCDesign.secondary)
                    } else if source == "custom" {
                        TextField("Write your own line", text: $custom, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                HCSectionTitle(title: "Voice & tone")
                HCCard {
                    Picker("Tone", selection: $tone) {
                        Text("Quiet").tag("quiet")
                        Text("Direct").tag("direct")
                        Text("Rigorous").tag("rigorous")
                    }
                    .pickerStyle(.segmented)
                    Text("Tone will shape future prompts. Your current daily note remains the selected source's original text.")
                        .font(.caption2).foregroundStyle(HCDesign.secondary)
                }
 
            }
            .padding(18)
        }
        .hcPage()
        .navigationTitle("Motivation")
        .onAppear(perform: importLegacyFavorite)
    }
}
