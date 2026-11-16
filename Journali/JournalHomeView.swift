import SwiftUI

struct JournalHomeView: View {
    @ObservedObject var journal: JournalViewModel
    @State private var editorDraft: JournalDraft?
    @State private var entryToDelete: JournalEntry?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(JournalPalette.background.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if #available(iOS 26, *) {
                        ToolbarItem(placement: .topBarLeading) {
                            journalTitle
                        }
                        .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .topBarLeading) {
                            journalTitle
                        }
                    }

                    ToolbarItemGroup(placement: .topBarTrailing) {
                        sortMenu
                        addEntryButton
                    }
                }
                .searchable(text: $journal.searchText, prompt: "Search")
        }
        .sheet(item: $editorDraft) { draft in
            JournalEditorView(draft: draft) { editedDraft in
                try journal.save(editedDraft)
                if editedDraft.isNew { journal.searchText = "" }
            }
        }
        .alert("Delete Journal?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { isPresented in
                if !isPresented { entryToDelete = nil }
            }
        ), presenting: entryToDelete) { entry in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                performJournalAction { try journal.delete(entry) }
            }
        } message: { entry in
            Text("Are you sure you want to delete “\(entry.displayTitle)”?")
        }
        .alert("Journali", isPresented: Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Screen content

    private var journalTitle: some View {
        Text("Journal")
            .journalFont(.headingLarge)
            .foregroundStyle(JournalPalette.primaryText)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityAddTraits(.isHeader)
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
                Text("Try a different word or phrase.")
            } actions: {
                Button("Clear Search") {
                    journal.searchText = ""
                }
                .buttonStyle(.bordered)
            }
        } else {
            List(journal.visibleEntries) { entry in
                JournalEntryCard(entry: entry) {
                    openEditor(for: entry)
                } onBookmark: {
                    performJournalAction { try journal.toggleBookmark(entry) }
                }
                .accessibilityAction(named: Text("Delete Entry")) { entryToDelete = entry }
                .listRowInsets(EdgeInsets(top: 8, leading: 21, bottom: 8, trailing: 21))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading, allowsFullSwipe: false) { deleteAction(for: entry) }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) { deleteAction(for: entry) }
            }
            .listStyle(.plain)
            .contentMargins(.top, 16, for: .scrollContent)
            .scrollContentBackground(.hidden)
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
                        .foregroundStyle(JournalPalette.primaryText)
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

    // MARK: - Toolbar buttons

    private var sortMenu: some View {
        Menu {
            Button(JournalOrder.bookmark.title) {
                journal.order = .bookmark
            }
            Divider()
            Button(JournalOrder.date.title) {
                journal.order = .date
            }
        } label: {
            Label("Sort entries", systemImage: "line.3.horizontal.decrease")
                .labelStyle(.iconOnly)
        }
        .menuOrder(.fixed)
        .accessibilityValue(journal.order == .date ? "Newest first" : "Bookmarked first")
        .tint(JournalPalette.primaryText)
    }

    private var addEntryButton: some View {
        Button {
            openEditor()
        } label: {
            Label("Add journal entry", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .disabled(journal.loadError != nil)
        .tint(JournalPalette.primaryText)
    }

    // MARK: - Entry actions

    private func deleteAction(for entry: JournalEntry) -> some View {
        Button {
            entryToDelete = entry
        } label: {
            Label("Delete", systemImage: "trash.fill")
        }
        .tint(JournalPalette.destructive)
    }

    private func openEditor(for entry: JournalEntry? = nil) {
        editorDraft = JournalDraft(entry: entry)
    }

    private func performJournalAction(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Entry card

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
                            .padding(.top, 16)
                    }
                }
                .padding(.vertical, 23)
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityHint("Opens the editor")

            Button(action: onBookmark) {
                Image(systemName: entry.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(JournalPalette.accentText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(entry.isBookmarked ? "Remove bookmark" : "Bookmark entry")
            .padding(12)
        }
        .buttonStyle(.plain)
        .background(JournalPalette.surface, in: RoundedRectangle(cornerRadius: 30))
    }
}
