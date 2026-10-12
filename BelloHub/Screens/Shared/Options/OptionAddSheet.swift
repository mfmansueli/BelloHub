//
//  OptionAddSheet.swift
//  BelloHub
//

import SwiftUI

/// "+ Add" for a list of descriptive options (a technique, a product, a preference, a choice of her own field), opened
/// as a small sheet so she never leaves the visit. As she types, the options she already has are suggested; tapping
/// one uses it. A new name is created and selected at once, used only this time or saved to reuse, as she chooses.
/// The same name with other spaces or letter case is the existing option, never a second one (`OptionNameRules`).
struct OptionAddSheet: View {
    let title: Text
    /// What she already has in this list, offered as she types.
    let existing: [String]
    /// False when the list cannot keep new options (the choice is then hidden).
    var canSave = true
    /// The name to use, and whether to save it for reuse.
    let onAdd: (String, Bool) -> Void

    @State private var text = ""
    @State private var saveForReuse = true
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    // The field's name can be long in any language: it wraps here instead of being cut in the bar.
                    title
                        .font(Typography.section)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    field
                    suggestions
                    if let created = newName { createRow(created) }
                    if canSave, newName != nil { scope }
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.vertical, Spacing.md)
            }
            .background(Palette.bg)
            .navigationTitle(Text("optionAdd.chip"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("optionAdd.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: confirm) { Text("optionAdd.add") }
                        .disabled(!OptionNameRules.isValid(text))
                        .accessibilityIdentifier("optionAdd.confirm")
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.bg)
    }

    // MARK: - Parts

    private var field: some View {
        TextField(text: $text, prompt: Text.prompt("optionAdd.prompt")) { title }
            .font(Typography.body)
            .foregroundStyle(Palette.ink)
            .focused($isFocused)
            .submitLabel(.done)
            .onSubmit(confirm)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 52)
            .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                    .strokeBorder(isFocused ? Palette.roseText : Palette.fieldBorder, lineWidth: isFocused ? 3 : 1.5)
            }
            .accessibilityIdentifier("optionAdd.field")
    }

    @ViewBuilder
    private var suggestions: some View {
        let found = OptionNameRules.suggestions(for: text, in: existing)
        if !found.isEmpty {
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                ForEach(found, id: \.self) { name in
                    Button { use(name, save: false) } label: { Text(verbatim: name) }
                        .buttonStyle(.belloChip(selected: false))
                        .accessibilityIdentifier("optionAdd.suggestion.\(name)")
                }
            }
        }
    }

    private func createRow(_ name: String) -> some View {
        Button(action: confirm) {
            Label {
                Text(LocalizedStringResource("optionAdd.create", defaultValue: "Create “\(name)”")
                    .localized(in: locale))
            } icon: {
                Image(icon: .plus)
            }
            .font(Typography.bodyStrong)
            .foregroundStyle(Palette.roseText)
            .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
        }
        .accessibilityIdentifier("optionAdd.create")
    }

    private var scope: some View {
        Picker(selection: $saveForReuse) {
            Text("optionAdd.scope.once").tag(false)
            Text("optionAdd.scope.save").tag(true)
        } label: {
            Text("optionAdd.scope")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("optionAdd.scope")
    }

    // MARK: - Actions

    /// The typed name when it is new; nil when empty or already in the list (then its suggestion is the way).
    private var newName: String? {
        let cleaned = OptionNameRules.normalized(text)
        guard OptionNameRules.isValid(cleaned), OptionNameRules.match(cleaned, in: existing) == nil else { return nil }
        return cleaned
    }

    private func confirm() {
        guard OptionNameRules.isValid(text) else { return }
        if let same = OptionNameRules.match(text, in: existing) {
            use(same, save: false)
        } else {
            use(OptionNameRules.normalized(text), save: canSave && saveForReuse)
        }
    }

    private func use(_ name: String, save: Bool) {
        onAdd(name, save)
        dismiss()
    }
}
