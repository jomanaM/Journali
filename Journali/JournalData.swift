import Combine
import Foundation

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var text: String
    let date: Date
    var isBookmarked: Bool

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled" : trimmedTitle
    }
}

struct JournalDraft: Identifiable {
    let id: UUID
    let date: Date
    var title: String
    var text: String

    private let original: JournalEntry?

    init(entry: JournalEntry? = nil) {
        original = entry
        id = entry?.id ?? UUID()
        date = entry?.date ?? Date()
        title = entry?.title ?? ""
        text = entry?.text ?? ""
    }

    var isNew: Bool { original == nil }

    var hasChanges: Bool {
        title != (original?.title ?? "") || text != (original?.text ?? "")
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum JournalOrder: CaseIterable, Identifiable {
    case date
    case bookmark

    var id: Self { self }

    var title: String {
        switch self {
        case .date: "Sort by Entry Date"
        case .bookmark: "Sort by Bookmark"
        }
    }

    var icon: String {
        switch self {
        case .date: "calendar"
        case .bookmark: "bookmark"
        }
    }
}

@MainActor
final class JournalViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var order: JournalOrder = .date
    @Published var bookmarksOnly = false
    @Published var selectedDate: Date?
    @Published private(set) var entries: [JournalEntry] = []
    @Published private(set) var loadError: String?

    private let store: JournalFileStore

    init(storageURL: URL? = nil) {
        store = JournalFileStore(url: storageURL ?? JournalFileStore.defaultURL)
        reload()
    }

    var visibleEntries: [JournalEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries
            .filter { entry in
                if bookmarksOnly && !entry.isBookmarked { return false }
                if let selectedDate, !Calendar.current.isDate(entry.date, inSameDayAs: selectedDate) {
                    return false
                }
                return query.isEmpty || entry.displayTitle.localizedStandardContains(query) ||
                    entry.text.localizedStandardContains(query)
            }
            .sorted { first, second in
                if order == .bookmark && first.isBookmarked != second.isBookmarked {
                    return first.isBookmarked
                }
                return first.date > second.date
            }
    }

    func clearFilters() {
        searchText = ""
        bookmarksOnly = false
        selectedDate = nil
    }

    func reload() {
        do {
            entries = try store.read()
            loadError = nil
        } catch {
            loadError = "Journali couldn’t open your saved entries. Try loading them again."
        }
    }

    func save(_ draft: JournalDraft) throws {
        guard draft.canSave else { throw JournalDataError.emptyEntry }
        var updatedEntries = entries
        if let index = updatedEntries.firstIndex(where: { $0.id == draft.id }) {
            updatedEntries[index].title = draft.title
            updatedEntries[index].text = draft.text
        } else {
            guard draft.isNew else { throw JournalDataError.missingEntry }
            updatedEntries.append(JournalEntry(
                id: draft.id,
                title: draft.title,
                text: draft.text,
                date: draft.date,
                isBookmarked: false
            ))
        }
        try commit(updatedEntries)
    }

    func toggleBookmark(_ entry: JournalEntry) throws {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw JournalDataError.missingEntry
        }
        var updatedEntries = entries
        updatedEntries[index].isBookmarked.toggle()
        try commit(updatedEntries)
    }

    func delete(_ entry: JournalEntry) throws {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw JournalDataError.missingEntry
        }
        var updatedEntries = entries
        updatedEntries.remove(at: index)
        try commit(updatedEntries)
    }

    private func commit(_ updatedEntries: [JournalEntry]) throws {
        // A read failure must not let an empty list overwrite the saved journal.
        guard loadError == nil else { throw JournalDataError.readFailed }
        guard updatedEntries != entries else { return }
        do {
            try store.write(updatedEntries)
        } catch {
            throw JournalDataError.writeFailed
        }
        entries = updatedEntries
    }
}

private struct JournalFileStore {
    static var defaultURL: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("Journali", isDirectory: true)
            .appendingPathComponent("entries.json")
    }

    let url: URL

    func read() throws -> [JournalEntry] {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([JournalEntry].self, from: data)
        } catch let error as CocoaError
            where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return []
        }
    }

    func write(_ entries: [JournalEntry]) throws {
        let data = try JSONEncoder().encode(entries)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}

private enum JournalDataError: LocalizedError {
    case emptyEntry
    case missingEntry
    case readFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .emptyEntry: "Add a title or write something before saving."
        case .missingEntry: "This entry is no longer in your journal."
        case .readFailed: "Reload your saved entries before making changes."
        case .writeFailed: "Journali couldn’t save your changes. Please try again."
        }
    }
}
