//
//  TagEditorSheet.swift
//  BelloHub
//

import SwiftUI

/// The sheet for one tag: "New tag" (name and color, "Add tag") or an existing tag (rename, recolor, delete). Opens as
/// a native sheet. The name is checked while she types by the same rule that decides on save (`TagRules`), so a name
/// that is taken or too long says so under the field instead of failing after the tap.
struct TagEditorSheet: View {
    let mode: TagEditorMode
    let viewModel: TagsViewModel

    @State private var name: String
    @State private var color: TagColor
    @State private var isSaving = false
    @State private var pendingDeletion: Tag?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale
    @FocusState private var isFocused: Bool

    init(mode: TagEditorMode, viewModel: TagsViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        _name = State(initialValue: mode.tag?.name ?? "")
        _color = State(initialValue: mode.tag.map { TagColor(token: $0.colorToken) } ?? viewModel.suggestedColor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let message = viewModel.saveErrorMessage {
                        ErrorNotice(message: message)
                    }
                    BelloTextField(
                        title: "tags.editor.name", text: $name, prompt: "tags.editor.namePrompt",
                        errorMessage: nameError, identifier: "tagEditor.nameField"
                    )
                    .focused($isFocused)
                    colorChoice
                    if let tag = mode.tag { deleteButton(for: tag) }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg)
            .navigationTitle(Text(mode.tag == nil ? "tags.editor.addTitle" : "tags.editor.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("tagEditor.cancelButton")
                }
            }
            .safeAreaInset(edge: .bottom) { saveButton }
            .onSubmit { if canSave { save() } }
            .onAppear { isFocused = mode.tag == nil }
            .onDisappear { viewModel.dismissSaveError() }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.bg)
        .tagDeletionDialog(
            $pendingDeletion, clientCount: viewModel.clientCount(for:), onConfirm: delete
        )
    }

    // MARK: - Parts

    /// Four buttons, one per semantic color. A system `ColorPicker` offers any color; a tag may only use the four of
    /// the palette (stored as tokens, with measured contrast), so the choice is built from them.
    private var colorChoice: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("tags.editor.color").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(TagColor.allCases) { option in
                    colorButton(option)
                }
            }
        }
    }

    private var columns: [GridItem] {
        let count = typeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: count)
    }

    private func colorButton(_ option: TagColor) -> some View {
        let isSelected = option == color
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        return Button { color = option } label: {
            HStack(spacing: Spacing.row) {
                TagDot(color: option, size: 24)
                Text(option.name.localized(in: locale)).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                if isSelected {
                    Image(icon: .check)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.onAction)
                        .frame(width: 28, height: 28)
                        .background(Palette.action, in: Circle())
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(isSelected ? Palette.surface : Palette.sunken, in: shape)
            .overlay { if isSelected { shape.strokeBorder(Palette.action, lineWidth: 1.5) } }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("tagEditor.color.\(option.token)")
    }

    private func deleteButton(for tag: Tag) -> some View {
        Button { pendingDeletion = tag } label: { Text("tags.editor.delete") }
            .buttonStyle(.belloDestructive)
            .padding(.top, Spacing.sm)
            .accessibilityIdentifier("tagEditor.deleteButton")
    }

    private var saveButton: some View {
        Button(action: save) {
            if isSaving {
                ProgressView()
            } else {
                Text(mode.tag == nil ? "tags.editor.add" : "tags.editor.save")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(!canSave || isSaving)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("tagEditor.saveButton")
    }

    // MARK: - Rules

    private var check: TagNameCheck { viewModel.checkName(name, editing: mode.tag?.id) }

    private var canSave: Bool { check.acceptedName != nil }

    /// Shown only for a name that is wrong, not for an empty field she has not typed in yet.
    private var nameError: LocalizedStringKey? {
        switch check {
        case .duplicate: "tags.error.duplicate"
        case .tooLong: "tags.error.tooLong"
        case .empty, .accepted: nil
        }
    }

    // MARK: - Actions

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        Task {
            let saved = await viewModel.save(name: name, color: color, editing: mode.tag)
            isSaving = false
            if saved { dismiss() }
        }
    }

    private func delete(_ tag: Tag) {
        Task {
            if await viewModel.delete(tag) { dismiss() }
        }
    }
}

#Preview {
    let profile = ProfileService(vault: VaultService(repository: nil))
    return TagEditorSheet(mode: .add, viewModel: TagsViewModel(profile: profile, clients: nil))
}
