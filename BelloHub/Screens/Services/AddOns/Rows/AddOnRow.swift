//
//  AddOnRow.swift
//  BelloHub
//

import SwiftUI

/// One add-on in the list: the extra time and price under its name, and the switch that offers it to clients. Two
/// controls in one row (the area that opens the add-on, and the switch), so the row is not one combined element; the
/// switch is named after the add-on so VoiceOver says what it turns on.
struct AddOnRow: View {
    let addOn: AddOn
    let formatters: Formatters
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Spacing.row) {
            Button(action: onEdit) {
                HStack(spacing: Spacing.row) {
                    Image(icon: .sparkle)
                        .foregroundStyle(Palette.sageText)
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                        .background(
                            Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        )
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(verbatim: addOn.name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                        Text(verbatim: details).font(Typography.meta).foregroundStyle(Palette.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, Spacing.sm)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("addOns.row.hint"))
            .accessibilityIdentifier("addOns.row.\(addOn.id.uuidString)")
            Toggle(isOn: Binding(get: { addOn.isOffered }, set: { onToggle($0) })) { Text(verbatim: addOn.name) }
                .labelsHidden()
                .tint(Palette.sage)
                .accessibilityLabel(Text(verbatim: addOn.name))
                .accessibilityIdentifier("addOns.toggle.\(addOn.id.uuidString)")
        }
    }

    /// "+15 min · R$20", or just the time when there is no price.
    private var details: String {
        let extra = String(localized: LocalizedStringResource(
            "addOns.row.extra", defaultValue: "+\(formatters.minutes(addOn.minutes))"
        ).localized(in: locale))
        return [extra, addOn.priceAmount.map(formatters.money)].compactMap { $0 }.joined(separator: " · ")
    }
}
