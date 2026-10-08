//
//  FieldEditorSheet.swift
//  BelloHub
//

import SwiftUI

/// The sheet for one of her own fields: "Add your own field" (name and "How do you fill it?") or an existing field
/// (rename it, change its options or unit, delete it). Opens as a native sheet. What is wrong is said under the part of
/// the form that needs fixing, while she types, by the same rule that decides on save (`RecordTemplateEditor`).
struct FieldEditorSheet: View {
    let mode: FieldEditorMode
    let viewModel: RecordTemplateViewModel

    @State private var draft: RecordFieldDraft
    @State private var isSaving = false
    @State private var pendingDeletion: RecordFieldSetting?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @FocusState private var isFocused: Bool

    init(mode: FieldEditorMode, viewModel: RecordTemplateViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        _draft = State(initialValue: mode.field.map(RecordFieldDraft.init(editing:)) ?? RecordFieldDraft())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let message = viewModel.errorMessage { ErrorNotice(message: message) }
                    if issue == .notFound {
                        InlineNotice(style: .warning, title: "fieldEditor.error.notFound")
                    }
                    BelloTextField(
                        title: "fieldEditor.name", text: $draft.name, prompt: "fieldEditor.namePrompt",
                        errorMessage: nameError, identifier: "fieldEditor.nameField"
                    )
                    .focused($isFocused)
                    kindChoice
                    if draft.kind == .choice { optionsField }
                    if draft.kind == .number { unitField }
                    if let field = mode.field { deleteButton(for: field) }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .navigationTitle(Text(mode.field == nil ? "fieldEditor.addTitle" : "fieldEditor.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("fieldEditor.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { saveButton }
            .onAppear { isFocused = mode.field == nil }
            .onDisappear { viewModel.dismissError() }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
        .fieldDeletionDialog($pendingDeletion, name: viewModel.name(of:), onConfirm: delete)
    }

    // MARK: - Parts

    /// How she fills the field. A menu: four choices fit a menu better than a segmented control, whose labels would be
    /// clipped in most languages. The kind is fixed once the field exists, because changing it would make what saved
    /// records hold for the field mean something else.
    private var kindChoice: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("fieldEditor.kind").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            Picker(selection: $draft.kind) {
                ForEach(RecordFieldKind.allCases) { kind in
                    Text(kind.title.localized(in: locale)).tag(kind)
                }
            } label: { Text("fieldEditor.kind") }
                .pickerStyle(.menu)
                .tint(Palette.ink)
                .disabled(mode.field != nil)
                .padding(.horizontal, Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(Palette.sunken, in: fieldShape)
                .overlay { fieldShape.strokeBorder(Palette.fieldBorder, lineWidth: 1.5) }
                .accessibilityIdentifier("fieldEditor.kindPicker")
            if mode.field != nil {
                Text("fieldEditor.kind.locked").font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
        }
    }

    /// One option per line. A text field that grows with its lines: `BelloTextField` is one line, and a list of
    /// options is naturally one per line.
    private var optionsField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("fieldEditor.options").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            TextField(text: $draft.optionsText, prompt: .prompt("fieldEditor.optionsPrompt"), axis: .vertical) {
                Text("fieldEditor.options")
            }
            .lineLimit(3...8)
            .font(Typography.body)
            .foregroundStyle(Palette.ink)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            .background(Palette.sunken, in: fieldShape)
            .overlay { fieldShape.strokeBorder(optionsBorder, lineWidth: 1.5) }
            .accessibilityHint(optionsError.map { Text($0) } ?? Text(verbatim: ""))
            .accessibilityIdentifier("fieldEditor.optionsField")
            if let optionsError {
                Text(optionsError).font(Typography.footnote).foregroundStyle(Palette.coralText)
            } else {
                Text("fieldEditor.optionsHint").font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
        }
    }

    private var unitField: some View {
        BelloTextField(
            title: "fieldEditor.unit", text: $draft.unit, prompt: "fieldEditor.unitPrompt",
            errorMessage: issue == .unitTooLong ? "fieldEditor.error.unitTooLong" : nil,
            identifier: "fieldEditor.unitField"
        )
    }

    private func deleteButton(for field: RecordFieldSetting) -> some View {
        Button { pendingDeletion = field } label: { Text("fieldEditor.delete") }
            .buttonStyle(.belloDestructive)
            .padding(.top, Spacing.sm)
            .accessibilityIdentifier("fieldEditor.deleteButton")
    }

    private var saveButton: some View {
        Button(action: save) {
            if isSaving {
                ProgressView()
            } else {
                Text(mode.field == nil ? "fieldEditor.add" : "fieldEditor.save")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(issue != nil || isSaving)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("fieldEditor.saveButton")
    }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
    }

    private var optionsBorder: Color {
        optionsError == nil ? Palette.fieldBorder : Palette.coralText
    }

    // MARK: - Rules

    private var issue: RecordFieldIssue? { viewModel.issue(in: draft, editing: mode.field?.key) }

    /// Shown only for a name that is wrong, not for an empty field she has not typed in yet.
    private var nameError: LocalizedStringKey? {
        switch issue {
        case .nameTooLong: "fieldEditor.error.nameTooLong"
        case .nameTaken: "fieldEditor.error.nameTaken"
        default: nil
        }
    }

    /// Shown once she has typed an option: "at least two" is the hint until then, not an accusation.
    private var optionsError: LocalizedStringKey? {
        switch issue {
        case .optionTooLong: "fieldEditor.error.optionTooLong"
        case .tooManyOptions: "fieldEditor.error.tooManyOptions"
        case .tooFewOptions where !draft.options.isEmpty: "fieldEditor.error.tooFewOptions"
        default: nil
        }
    }

    // MARK: - Actions

    private func save() {
        guard issue == nil, !isSaving else { return }
        isSaving = true
        Task {
            let saved: Bool
            if let field = mode.field {
                saved = await viewModel.updateField(field.key, with: draft)
            } else {
                saved = await viewModel.addField(draft)
            }
            isSaving = false
            if saved { dismiss() }
        }
    }

    private func delete(_ field: RecordFieldSetting) {
        Task {
            if await viewModel.deleteField(field.key) { dismiss() }
        }
    }
}
