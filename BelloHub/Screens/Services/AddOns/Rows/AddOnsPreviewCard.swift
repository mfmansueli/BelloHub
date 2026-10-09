//
//  AddOnsPreviewCard.swift
//  BelloHub
//

import SwiftUI

/// "What clients see": a sage card that explains the booking step and shows the add-ons that are switched on, each with
/// its extra time. It reads the same list the switches change, so it is the preview of the switches.
struct AddOnsPreviewCard: View {
    let offered: [AddOn]
    let formatters: Formatters

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("addOns.preview.title").font(Typography.bodyStrong).foregroundStyle(Palette.sageText)
                .accessibilityAddTraits(.isHeader)
            Text("addOns.preview.message").font(Typography.meta).foregroundStyle(Palette.sageText)
            if !offered.isEmpty {
                FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                    ForEach(offered) { addOn in
                        Text(verbatim: chip(for: addOn))
                            .font(Typography.metaStrong).foregroundStyle(Palette.ink)
                            .padding(.horizontal, Spacing.row)
                            .padding(.vertical, Spacing.sm)
                            .background(Palette.surface, in: Capsule())
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// "Eyebrow tint +15 min".
    private func chip(for addOn: AddOn) -> String {
        String(localized: LocalizedStringResource(
            "addOns.preview.chip", defaultValue: "\(addOn.name) +\(formatters.minutes(addOn.minutes))"
        ).localized(in: locale))
    }
}
