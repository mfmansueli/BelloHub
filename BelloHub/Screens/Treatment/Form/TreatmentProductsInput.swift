//
//  TreatmentProductsInput.swift
//  BelloHub
//

import SwiftUI

/// "Products used": what she used, one chip each. She types a product and adds it, or taps one from her own product
/// list; a chip's cross removes it. The list is stored as lines (`TreatmentAnswerFormat`).
struct TreatmentProductsInput: View {
    let title: String
    @Binding var value: String
    /// The names in her product list, offered as one-tap suggestions.
    let suggestions: [String]
    let idPrefix: String
    /// "+ Add" (with the choice to save the product to her list); nil keeps only the inline field.
    var onAdd: (() -> Void)?

    @Environment(\.locale) private var locale
    @State private var typed = ""
    @FocusState private var isFocused: Bool

    private var items: [String] { TreatmentAnswerFormat.items(value) }

    private var remainingSuggestions: [String] {
        suggestions.filter { name in !items.contains { $0.caseInsensitiveCompare(name) == .orderedSame } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(verbatim: title).font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            if !items.isEmpty { chosen }
            addRow
            if !remainingSuggestions.isEmpty || onAdd != nil { suggestionRow }
        }
    }

    // MARK: - Parts

    private var chosen: some View {
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
            ForEach(items, id: \.self) { item in
                Button { value = TreatmentAnswerFormat.join(items.filter { $0 != item }) } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(verbatim: item)
                        Image(icon: .close).font(.system(size: 11, weight: .bold)).accessibilityHidden(true)
                    }
                }
                .buttonStyle(.belloChip(selected: true))
                .accessibilityLabel(Text(
                    LocalizedStringResource("treatmentFlow.form.products.remove", defaultValue: "Remove \(item)")
                        .localized(in: locale)
                ))
                .accessibilityIdentifier("\(idPrefix).chip.\(item)")
            }
        }
    }

    private var addRow: some View {
        HStack(spacing: Spacing.sm) {
            TextField(text: $typed, prompt: Text.prompt("treatmentFlow.form.products.prompt")) {
                Text(verbatim: title)
            }
            .font(Typography.body)
            .foregroundStyle(Palette.ink)
            .focused($isFocused)
            .submitLabel(.done)
            .onSubmit(add)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 52)
            .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                    .strokeBorder(isFocused ? Palette.roseText : Palette.fieldBorder, lineWidth: isFocused ? 3 : 1.5)
            }
            .accessibilityIdentifier("\(idPrefix).input")
            Button(action: add) {
                Image(icon: .plus)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.onAction)
                    .frame(width: Spacing.touchTarget + 8, height: Spacing.touchTarget + 8)
                    .background(Palette.action, in: Circle())
            }
            .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(Text("treatmentFlow.form.products.add"))
            .accessibilityIdentifier("\(idPrefix).addButton")
        }
    }

    private var suggestionRow: some View {
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
            ForEach(remainingSuggestions, id: \.self) { name in
                Button { value = TreatmentAnswerFormat.join(TreatmentAnswerFormat.adding(name, to: items)) } label: {
                    Text(verbatim: name)
                }
                .buttonStyle(.belloChip(selected: false))
                .accessibilityIdentifier("\(idPrefix).suggestion.\(name)")
            }
            if let onAdd { AddOptionChip(identifier: "\(idPrefix).addOption", action: onAdd) }
        }
    }

    private func add() {
        value = TreatmentAnswerFormat.join(TreatmentAnswerFormat.adding(typed, to: items))
        typed = ""
    }
}
