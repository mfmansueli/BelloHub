//
//  QuickReplyEditorSheet.swift
//  BelloHub
//

import SwiftUI

/// One quick reply: its name, its message, buttons that add the words in curly braces, a preview filled in for an
/// example client and the actions that fit it (save, back to the original for a built-in message, delete for one of
/// her own). A new reply becomes an edited one after its first save, so the same sheet carries on.
struct QuickReplyEditorSheet: View {
    let viewModel: QuickRepliesViewModel

    @State private var current: QuickReply?
    @State private var title: String
    @State private var text: String
    @State private var justSaved = false
    @State private var isWorking = false
    @State private var confirmsDelete = false
    @Environment(\.dismiss) private var dismiss

    init(mode: QuickReplyEditorMode, viewModel: QuickRepliesViewModel) {
        self.viewModel = viewModel
        _current = State(initialValue: mode.reply)
        _title = State(initialValue: mode.reply?.title ?? "")
        _text = State(initialValue: mode.reply?.text ?? "")
    }

    private var issue: QuickReplyIssue? { viewModel.issue(title: title, text: text) }

    private var unknownWords: [String] { viewModel.unknownWords(in: text) }

    /// The unfilled words as she wrote them: `{foo} {bar}`.
    private var unknownList: String { unknownWords.map { "{\($0)}" }.joined(separator: " ") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let message = viewModel.saveErrorMessage { ErrorNotice(message: message) }
                    BelloTextField(
                        title: "quickReplies.editor.name", text: $title, prompt: "quickReplies.editor.namePrompt",
                        errorMessage: nil, identifier: "quickReplyEditor.nameField"
                    )
                    messageField
                    words
                    previewCard
                    actions
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .navigationTitle(Text(current == nil ? "quickReplies.editor.addTitle" : "quickReplies.editor.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.close") }
                        .accessibilityIdentifier("quickReplyEditor.closeButton")
                }
            }
            .safeAreaInset(edge: .bottom) { saveButton }
            .onChange(of: text) { _, _ in justSaved = false }
            .onChange(of: title) { _, _ in justSaved = false }
            .onDisappear { viewModel.dismissSaveError() }
            .confirmationDialog(
                Text("quickReplies.editor.deleteTitle"), isPresented: $confirmsDelete, titleVisibility: .visible
            ) {
                Button(role: .destructive) { delete() } label: { Text("quickReplies.editor.delete") }
                    .accessibilityIdentifier("quickReplyEditor.deleteConfirmButton")
                Button(role: .cancel) {} label: { Text("common.cancel") }
            } message: {
                Text("quickReplies.editor.deleteMessage")
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    // MARK: - Parts

    private var messageField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            BelloNoteField(
                title: Text("quickReplies.editor.message"), text: $text, identifier: "quickReplyEditor.messageField"
            )
            if let issue, !text.isEmpty || issue == .textTooLong {
                Text(issueText(issue)).font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityIdentifier("quickReplyEditor.issue")
            }
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("quickReplies.editor.insert").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                ForEach(QuickReplyVariable.allCases) { variable in
                    Button { text = QuickReplyRules.appending(variable, to: text) } label: {
                        Text(verbatim: variable.token)
                    }
                    .buttonStyle(.belloChip(selected: false))
                    .accessibilityHint(Text(LocalizedStringResource(
                        "quickReplies.editor.insertHint", defaultValue: "Adds \(variable.token) to the message."
                    )))
                    .accessibilityIdentifier("quickReplyEditor.word.\(variable.rawValue)")
                }
            }
            if !unknownWords.isEmpty {
                Text(LocalizedStringResource(
                    "quickReplies.editor.unknown",
                    defaultValue: "Not filled in: \(unknownList). They are sent as written."
                ))
                .font(Typography.footnote).foregroundStyle(Palette.amberText)
                .accessibilityIdentifier("quickReplyEditor.unknownWords")
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("quickReplies.editor.preview").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: viewModel.preview(of: text))
                .font(Typography.body).foregroundStyle(Palette.sageText)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .accessibilityIdentifier("quickReplyEditor.preview")
            Text("quickReplies.editor.previewNote").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if let current, viewModel.isEdited(current) {
            Button { reset(current) } label: { Text("quickReplies.editor.reset") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("quickReplyEditor.resetButton")
        }
        if let current, current.builtIn == nil {
            Button { confirmsDelete = true } label: { Text("quickReplies.editor.delete") }
                .buttonStyle(.belloDestructive)
                .accessibilityIdentifier("quickReplyEditor.deleteButton")
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            if isWorking {
                ProgressView()
            } else {
                Text(justSaved ? "quickReplies.editor.saved" : "quickReplies.editor.save")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(issue != nil || justSaved || isWorking)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("quickReplyEditor.saveButton")
    }

    private func issueText(_ issue: QuickReplyIssue) -> LocalizedStringKey {
        switch issue {
        case .nameEmpty: "quickReplies.editor.error.name"
        case .textEmpty: "quickReplies.editor.error.empty"
        case .textTooLong: "quickReplies.editor.error.tooLong"
        }
    }

    // MARK: - Actions

    private func save() {
        guard issue == nil, !isWorking else { return }
        isWorking = true
        Task {
            let saved: QuickReply?
            if let current {
                saved = await viewModel.save(current, title: title, text: text)
            } else {
                saved = await viewModel.add(title: title, text: text)
            }
            isWorking = false
            if let saved {
                current = saved
                title = saved.title
                text = saved.text
                justSaved = true
            }
        }
    }

    private func reset(_ reply: QuickReply) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            if let original = await viewModel.resetToOriginal(reply) {
                current = original
                title = original.title
                text = original.text
                justSaved = true
            }
            isWorking = false
        }
    }

    private func delete() {
        guard let current, !isWorking else { return }
        isWorking = true
        Task {
            let deleted = await viewModel.delete(current)
            isWorking = false
            if deleted { dismiss() }
        }
    }
}
