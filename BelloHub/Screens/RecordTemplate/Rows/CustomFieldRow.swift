//
//  CustomFieldRow.swift
//  BelloHub
//

import SwiftUI

/// One of her own fields in the "Yours" list: tap the name to edit it, and the switch asks for it or not. They are two
/// separate controls (the name opens the sheet, the switch changes the record form), so each is its own element for
/// VoiceOver: "Mood, Free text" and "Mood, switch button, on".
struct CustomFieldRow: View {
    let field: RecordFieldSetting
    let isOn: Binding<Bool>
    let onEdit: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Spacing.row) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: field.customName ?? field.key)
                        .font(isOn.wrappedValue ? Typography.bodyStrong : Typography.body)
                        .foregroundStyle(Palette.ink)
                    Text(verbatim: detail).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recordTemplate.custom.edit.\(field.key)")
            Toggle(isOn: isOn) { Text(verbatim: field.customName ?? field.key) }
                .labelsHidden()
                .tint(Palette.sage)
                .accessibilityLabel(Text(verbatim: field.customName ?? field.key))
                .accessibilityIdentifier("recordTemplate.custom.toggle.\(field.key)")
        }
        .padding(.horizontal, Spacing.md)
    }

    /// How she fills it: "Free text", the options she listed, or "Number · mm".
    private var detail: String {
        let kind = String(localized: field.kind.title.localized(in: locale))
        switch field.kind {
        case .choice where !field.options.isEmpty, .multiChoice where !field.options.isEmpty:
            return field.options.joined(separator: " · ")
        case .number:
            return field.unit.map { "\(kind) · \($0)" } ?? kind
        default:
            return kind
        }
    }
}
