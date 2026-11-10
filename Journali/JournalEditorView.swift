import SwiftUI

struct JournalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JournalDraft
    @State private var showDiscardAlert = false
    @State private var saveError: String?
    @FocusState private var focus: Field?

    private let onSave: (JournalDraft) throws -> Void

    private enum Field: Hashable {
        case title, text
    }

    init(draft: JournalDraft, onSave: @escaping (JournalDraft) throws -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(JournalPalette.primaryText)
                            .frame(width: 44, height: 44)
                            .background(JournalPalette.background.opacity(0.19), in: Circle())
                            .overlay(Circle().strokeBorder(JournalPalette.outline))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close editor")

                    Spacer()

                    Button(action: save) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(JournalPalette.background)
                            .frame(width: 44, height: 44)
                            .background(JournalPalette.action, in: Circle())
                            .opacity(draft.canSave ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!draft.canSave)
                    .accessibilityLabel("Save journal entry")
                }
                .padding(.top, 12)
                .padding(.bottom, 20)

                JournalEntryFields(draft: $draft, focus: $focus)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 640, maxHeight: .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .background(JournalPalette.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                }
            }
        }
        .presentationBackground(JournalPalette.surface)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(draft.hasChanges)
        .task {
            do {
                try await Task.sleep(for: .milliseconds(350))
                if focus == nil { focus = draft.isNew ? .title : .text }
            } catch {
                return
            }
        }
        .alert("Discard Changes?", isPresented: $showDiscardAlert) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard Changes", role: .destructive) { dismiss() }
        } message: {
            Text("Are you sure you want to discard changes to this journal entry?")
        }
        .alert("Couldn’t Save Entry", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private func close() {
        if draft.hasChanges {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func save() {
        do {
            if draft.isNew || draft.hasChanges { try onSave(draft) }
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private struct JournalEntryFields: View {
        @Binding var draft: JournalDraft
        let focus: FocusState<Field?>.Binding

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Title", text: $draft.title,
                          prompt: Text("Title").foregroundStyle(JournalPalette.secondaryText))
                    .journalFont(.headingLarge)
                    .foregroundStyle(JournalPalette.primaryText)
                    .accessibilityLabel("Title")
                    .focused(focus, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focus.wrappedValue = .text }

                Text(draft.date.journalDate)
                    .journalFont(.captionMedium)
                    .foregroundStyle(JournalPalette.secondaryText)
                    .accessibilityLabel(draft.date.formatted(date: .long, time: .omitted))

                TextEditor(text: $draft.text)
                    .journalFont(.bodyLarge)
                    .foregroundStyle(JournalPalette.primaryText)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .padding(.horizontal, -5)
                    .focused(focus, equals: .text)
                    .accessibilityLabel("Journal entry")
                    .overlay(alignment: .topLeading) {
                        if draft.text.isEmpty {
                            Text("Type your Journal…")
                                .journalFont(.bodyLarge)
                                .foregroundStyle(JournalPalette.secondaryText)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.top, 8)
            }
        }
    }
}
