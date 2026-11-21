import SwiftUI
import UIKit

/// IsAIah conversations belong to the signed-in account and remain on this
/// iPhone unless the athlete explicitly sends an excerpt to the AI service.
/// Separate thread records prevent "New chat" from discarding old work.
struct IMUNCoachSavedThread: Codable, Identifiable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var screen: String
    var messages: [IMUNCoachTurn]
}

@MainActor
final class IMUNCoachThreadLibrary: ObservableObject {
    static let shared = IMUNCoachThreadLibrary()
    @Published private(set) var threads: [IMUNCoachSavedThread] = []
    @Published private(set) var selectedID: UUID?
    @Published private(set) var owner: String?
    @Published private(set) var storageMessage: String?

    private init() {}

    private func archiveURL(for accountID: String) -> URL? {
        guard UUID(uuidString: accountID) != nil,
              let directory = FileManager.default.urls(
                  for: .applicationSupportDirectory,
                  in: .userDomainMask).first else { return nil }
        return directory.appendingPathComponent(
            "imun-isaiah-conversations-\(accountID.lowercased()).json")
    }

    private func save() {
        guard let owner, let url = archiveURL(for: owner) else { return }
        do {
            let folder = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder,
                                                     withIntermediateDirectories: true)
            let bytes = try JSONEncoder().encode(threads)
            try bytes.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path)
            storageMessage = nil
        } catch {
            storageMessage = "Your IsAIah conversation could not be saved locally."
        }
    }

    /// Reopening a screen must not reload a different account's local notes.
    /// Legacy unsandboxed conversations migrate to the first signed-in owner.
    func open(accountID: String?, legacy: [IMUNCoachTurn] = []) {
        guard let accountID, UUID(uuidString: accountID) != nil else {
            if owner != nil { threads = []; selectedID = nil; owner = nil }
            return
        }
        if owner == accountID && selectedID != nil { return }
        owner = accountID
        let url = archiveURL(for: accountID)
        if let url, let bytes = try? Data(contentsOf: url),
           let restored = try? JSONDecoder().decode([IMUNCoachSavedThread].self,
                                                    from: bytes) {
            threads = restored.sorted { $0.updatedAt > $1.updatedAt }
        } else {
            threads = []
        }
        if threads.isEmpty && !legacy.isEmpty {
            let migrated = IMUNCoachSavedThread(id: UUID(),
                title: "Previous IsAIah conversation",
                createdAt: Date(), updatedAt: Date(),
                screen: "Legacy iMun", messages: Array(legacy.suffix(250)))
            threads = [migrated]
            save()
        }
        if threads.isEmpty {
            create(screen: "iMun")
        } else {
            selectedID = threads[0].id
        }
    }

    var selected: IMUNCoachSavedThread? {
        threads.first(where: { $0.id == selectedID })
    }

    func create(screen: String) {
        guard owner != nil else { return }
        let now = Date()
        let item = IMUNCoachSavedThread(id: UUID(),
            title: "New conversation", createdAt: now, updatedAt: now,
            screen: String(screen.prefix(160)), messages: [])
        threads.insert(item, at: 0)
        selectedID = item.id
        save()
    }

    func select(_ id: UUID) {
        guard threads.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    func update(_ messages: [IMUNCoachTurn], screen: String) {
        guard let selectedID,
              let position = threads.firstIndex(where: { $0.id == selectedID })
        else { return }
        var item = threads[position]
        item.messages = Array(messages.suffix(160))
        item.updatedAt = Date()
        item.screen = String(screen.prefix(160))
        if item.title == "New conversation",
           let first = messages.first(where: { $0.role == "user" }) {
            let oneLine = first.text.replacingOccurrences(
                of: "\n", with: " ").trimmingCharacters(
                    in: .whitespacesAndNewlines)
            item.title = String(oneLine.prefix(65))
        }
        threads[position] = item
        threads.sort { $0.updatedAt > $1.updatedAt }
        save()
    }

    func delete(_ id: UUID) {
        threads.removeAll { $0.id == id }
        if selectedID == id {
            selectedID = threads.first?.id
        }
        if threads.isEmpty { create(screen: "iMun") }
        else { save() }
    }

    func clear() {
        threads = []
        selectedID = nil
        if let owner, let url = archiveURL(for: owner) {
            try? FileManager.default.removeItem(at: url)
        }
        if owner != nil { create(screen: "iMun") }
    }

    func relevantNotes(for query: String,
                       excluding current: Set<UUID>) -> String {
        let stop: Set<String> = [
            "about","with","your","that","this","what",
            "when","which","would","could","should","have",
            "training","workout","workouts","there","please"
        ]
        let terms = Set(query.lowercased().split(whereSeparator: {
            !$0.isLetter && !$0.isNumber
        }).map(String.init).filter { $0.count >= 4 }).subtracting(stop)
        let messages = threads.flatMap(\.messages).filter {
            $0.role == "user" && !current.contains($0.id)
        }
        let ranked = messages.enumerated().map { index, item in
            (index: index, text: item.text,
             hits: terms.filter {
                 item.text.lowercased().contains($0)
             }.count)
        }.sorted {
            if $0.hits != $1.hits { return $0.hits > $1.hits }
            return $0.index > $1.index
        }
        guard !ranked.isEmpty else { return "" }
        // Specific matching statements plus recent changing preferences.
        let best = Array(ranked.filter { $0.hits > 0 }.prefix(8))
        let recent = Array(ranked.sorted { $0.index > $1.index }.prefix(4))
        var used = Set<Int>()
        let combined = (best + recent).filter { used.insert($0.index).inserted }
        return String(combined.prefix(12).map {
            "Athlete previously wrote: " + String($0.text.prefix(340))
        }.joined(separator: "\n").prefix(4200))
    }
}

struct IMUNCoachHistorySheet: View {
    @ObservedObject var library: IMUNCoachThreadLibrary
    let onSelect: (UUID) -> Void
    let onCreate: () -> Void
    let onDelete: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var visible: [IMUNCoachSavedThread] {
        let clean = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return library.threads }
        return library.threads.filter { thread in
            thread.title.localizedCaseInsensitiveContains(clean) ||
            thread.messages.contains {
                $0.text.localizedCaseInsensitiveContains(clean)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if visible.isEmpty {
                    ContentUnavailableView("No conversations found",
                        systemImage: "bubble.left.and.text.bubble.right",
                        description: Text("Try a different search."))
                }
                ForEach(visible) { thread in
                    Button {
                        onSelect(thread.id)
                        dismiss()
                    } label: {
                        HStack(alignment: .center, spacing: 13) {
                            Image(systemName: thread.id == library.selectedID ?
                                  "bubble.left.and.bubble.right.fill" :
                                  "bubble.left.and.bubble.right")
                                .font(.system(size: 17, weight: .light))
                                .foregroundStyle(HCDesign.electric)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(thread.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(HCDesign.ink)
                                    .lineLimit(1)
                                Text(thread.updatedAt.formatted(
                                    date: .abbreviated, time: .shortened) +
                                    " · \(thread.messages.count) messages")
                                    .font(.system(size: 11))
                                    .foregroundStyle(HCDesign.secondary)
                            }
                            Spacer(minLength: 6)
                            if thread.id == library.selectedID {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(HCDesign.electric)
                            }
                        }
                        .padding(.vertical, 7)
                    }
                    .listRowBackground(HCDesign.card)
                    .swipeActions {
                        Button(role: .destructive) {
                            onDelete(thread.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search your conversations")
            .scrollContentBackground(.hidden)
            .background(HCDesign.canvas)
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onCreate()
                        dismiss()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Start a new conversation")
                }
            }
            .tint(HCDesign.electric)
        }
    }
}

struct IMUNCoachBubble: View {
    let turn: IMUNCoachTurn
    private var fromUser: Bool { turn.role == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if fromUser { Spacer(minLength: 46) }
            else {
                IMUNIsaiahMark(size: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .padding(.top, 3)
            }
            VStack(alignment: fromUser ? .trailing : .leading, spacing: 7) {
                Text(.init(turn.text))
                    .font(.system(size: 14))
                    .foregroundStyle(HCDesign.ink)
                    .textSelection(.enabled)
                    .tint(HCDesign.electric)
                    .lineSpacing(3)
                    .padding(.horizontal, fromUser ? 14 : 0)
                    .padding(.vertical, fromUser ? 12 : 0)
                    .background(fromUser ?
                                HCDesign.raised : Color.clear,
                                in: RoundedRectangle(cornerRadius: 17))
                    .frame(maxWidth: .infinity, alignment:
                           fromUser ? .trailing : .leading)
                if !fromUser {
                    Button {
                        UIPasteboard.general.string = turn.text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(HCDesign.secondary)
                    .accessibilityLabel("Copy IsAIah response")
                }
            }
            .frame(maxWidth: .infinity, alignment:
                   fromUser ? .trailing : .leading)
            if !fromUser { Spacer(minLength: 10) }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }
}
