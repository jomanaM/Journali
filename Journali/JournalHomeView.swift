import SwiftUI

struct JournalHomeView: View {
    @ObservedObject var journal: JournalViewModel
    @StateObject private var voiceSearch = JournalVoiceSearch()
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var searchFocused: Bool
    @State private var editorDraft: JournalDraft?
    @State private var pendingDelete: JournalEntry?
    @State private var presentedError: String?
    @State private var showDateFilter = false

    private var isFiltered: Bool { journal.bookmarksOnly || journal.selectedDate != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                JournalPalette.background.ignoresSafeArea()
                content
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { searchBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Journal")
                        .journalFont(.headingLarge)
                        .accessibilityAddTraits(.isHeader)
                }

                ToolbarItem(placement: .topBarTrailing) { journalControls }
            }
        }
        .sheet(item: $editorDraft) { draft in
            JournalEditorView(draft: draft) { editedDraft in
                try journal.save(editedDraft)
                if editedDraft.isNew { journal.clearFilters() }
            }
        }
        .sheet(isPresented: $showDateFilter) {
            JournalDateFilterView(initialDate: journal.selectedDate ?? .now) { date in
                journal.selectedDate = date
            }
        }
        .alert("Delete Journal?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), presenting: pendingDelete) { entry in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                perform { try journal.delete(entry) }
            }
        } message: { entry in
            Text("Are you sure you want to delete “\(entry.displayTitle)”?")
        }
        .alert("Journali", isPresented: Binding(
            get: { presentedError != nil }, set: { if !$0 { presentedError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(presentedError ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { voiceSearch.stop() }
        }
        .onDisappear { voiceSearch.stop() }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError = journal.loadError {
            ContentUnavailableView {
                Label("Couldn’t Open Journal", systemImage: "exclamationmark.circle")
            } description: {
                Text(loadError)
            } actions: {
                Button("Try Again") { journal.reload() }
                    .buttonStyle(.borderedProminent)
            }
        } else if journal.entries.isEmpty {
            emptyJournal
        } else if journal.visibleEntries.isEmpty {
            ContentUnavailableView {
                Label("No Matching Entries", systemImage: "magnifyingglass")
            } description: {
                Text("Try another search or clear your filters.")
            } actions: {
                Button("Clear Search and Filters") {
                    voiceSearch.stop()
                    journal.clearFilters()
                    searchFocused = false
                }
                .buttonStyle(.bordered)
            }
        } else {
            List(journal.visibleEntries) { entry in
                JournalEntryCard(entry: entry) {
                    openEditor(for: entry)
                } onBookmark: {
                    perform { try journal.toggleBookmark(entry) }
                }
                .accessibilityAction(named: Text("Delete Entry")) { pendingDelete = entry }
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading, allowsFullSwipe: false) { deleteAction(for: entry) }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) { deleteAction(for: entry) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.vertical, 6, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var emptyJournal: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(spacing: 14) {
                    Image("EmptyNotebook")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 105)
                        .padding(.bottom, 12)
                        .accessibilityHidden(true)

                    Text("Begin Your Journal")
                        .journalFont(.headingMedium)
                        .foregroundStyle(JournalPalette.accentText)
                        .accessibilityAddTraits(.isHeader)

                    Text("Craft your personal diary, tap the plus icon to begin")
                        .journalFont(.supporting)
                        .foregroundStyle(JournalPalette.secondaryText)
                        .frame(maxWidth: 295)
                }
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: viewport.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var journalControls: some View {
        HStack(spacing: 0) {
            Menu {
                Picker("Sort Entries", selection: $journal.order) {
                    ForEach(JournalOrder.allCases) { order in
                        Label(order.title, systemImage: order.icon).tag(order)
                    }
                }
                Section {
                    Toggle(isOn: $journal.bookmarksOnly) {
                        Label("Bookmarks Only", systemImage: "bookmark.fill")
                    }
                    Button {
                        voiceSearch.stop()
                        searchFocused = false
                        showDateFilter = true
                    } label: {
                        Label(journal.selectedDate.map { "Date: \($0.journalDate)" } ?? "Filter by Date…",
                              systemImage: "calendar")
                    }
                    if journal.selectedDate != nil {
                        Button("Clear Date Filter", systemImage: "calendar.badge.minus") {
                            journal.selectedDate = nil
                        }
                    }
                }
            } label: {
                toolbarIcon("line.3.horizontal.decrease",
                            color: isFiltered ? JournalPalette.accentText : JournalPalette.primaryText)
            }
            .accessibilityLabel("Sort and filter entries")
            .accessibilityValue(isFiltered ? "Filters active" : "All entries")

            Button { openEditor() } label: {
                toolbarIcon("plus")
            }
            .disabled(journal.loadError != nil)
            .accessibilityLabel("Add journal entry")
        }
        .buttonStyle(.plain)
        .background(JournalPalette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(JournalPalette.outline).allowsHitTesting(false))
    }

    private func toolbarIcon(_ symbol: String, color: Color = JournalPalette.primaryText) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(JournalPalette.secondaryText)
                    .accessibilityHidden(true)

                TextField("Search", text: $journal.searchText,
                          prompt: Text("Search").foregroundStyle(JournalPalette.secondaryText))
                    .journalFont(.captionMedium)
                    .foregroundStyle(JournalPalette.primaryText)
                    .accessibilityLabel("Search journal")
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { searchFocused = false }
                    .onChange(of: searchFocused) { _, focused in
                        if focused { voiceSearch.stop() }
                    }

                if !journal.searchText.isEmpty {
                    Button {
                        voiceSearch.stop()
                        journal.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Clear search")
                }

                Button {
                    searchFocused = false
                    voiceSearch.toggle { transcript in
                        journal.searchText = transcript
                    } onError: { message in
                        presentedError = message
                    }
                } label: {
                    Image(systemName: voiceSearch.isListening ? "stop.circle.fill" : "mic")
                        .foregroundStyle(voiceSearch.isListening ? JournalPalette.accentText : JournalPalette.secondaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(voiceSearch.isListening ? "Stop voice search" : "Search by voice")
            }
            .padding(.leading, 14)
            .foregroundStyle(JournalPalette.secondaryText)
            .background(JournalPalette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(JournalPalette.outline).allowsHitTesting(false))

            if searchFocused {
                Button("Done") { searchFocused = false }
                    .journalFont(.captionMedium)
                    .foregroundStyle(JournalPalette.accentText)
                    .frame(minHeight: 44)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 680)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func deleteAction(for entry: JournalEntry) -> some View {
        Button {
            pendingDelete = entry
        } label: {
            Label("Delete", systemImage: "trash.fill")
        }
        .tint(JournalPalette.destructive)
    }

    private func openEditor(for entry: JournalEntry? = nil) {
        searchFocused = false
        voiceSearch.stop()
        editorDraft = JournalDraft(entry: entry)
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            presentedError = error.localizedDescription
        }
    }
}

private struct JournalEntryCard: View {
    let entry: JournalEntry
    let onOpen: () -> Void
    let onBookmark: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.displayTitle)
                        .journalFont(.cardTitle)
                        .foregroundStyle(JournalPalette.accentText)
                        .lineLimit(2)
                        .padding(.trailing, 40)

                    Text(entry.date.journalDate)
                        .journalFont(.captionSmall)
                        .foregroundStyle(JournalPalette.secondaryText)
                        .accessibilityLabel(entry.date.formatted(date: .long, time: .omitted))

                    if !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.text)
                            .journalFont(.bodyMedium)
                            .foregroundStyle(JournalPalette.primaryText)
                            .lineLimit(5)
                            .padding(.top, 9)
                    }
                }
                .padding(.vertical, 17)
                .padding(.horizontal, 21)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityHint("Opens the editor")

            Button(action: onBookmark) {
                Image(systemName: entry.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(JournalPalette.accentText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(entry.isBookmarked ? "Remove bookmark" : "Bookmark entry")
            .padding(7)
        }
        .buttonStyle(.plain)
        .background(JournalPalette.surface, in: RoundedRectangle(cornerRadius: 26))
        .padding(5)
        .background {
            RoundedRectangle(cornerRadius: 31)
                .fill(LinearGradient(colors: [Color(white: 0.39), Color(white: 0.17), Color(white: 0.38)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 31)
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private struct JournalDateFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    let onApply: (Date) -> Void

    init(initialDate: Date, onApply: @escaping (Date) -> Void) {
        _date = State(initialValue: initialDate)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                DatePicker("Entry date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)
            }
            .navigationTitle("Filter by Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(date)
                        dismiss()
                    }
                }
            }
        }
    }
}
