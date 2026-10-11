//
//  CatalogTypographySection.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// The type scale with the localized greeting, so Latin, Arabic and Devanagari render in every size.
struct CatalogTypographySection: View {
    private let scale: [(name: String, font: Font)] = [
        ("moment 40", Typography.moment), ("screenTitle 34", Typography.screenTitle), ("title 28", Typography.title),
        ("subtitle 24", Typography.subtitle), ("section 20", Typography.section), ("body 17", Typography.body),
        ("bodyStrong 17", Typography.bodyStrong), ("callout 16", Typography.callout),
        ("meta 15", Typography.meta), ("footnote 13", Typography.footnote), ("caption 12", Typography.caption)
    ]
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogSection(title: "Typography", identifier: "catalog.section.typography") {
            ForEach(scale, id: \.name) { entry in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: entry.name).font(Typography.caption).foregroundStyle(Palette.ink2)
                    Text(LocalizedStringResource("catalog.sample.greeting", defaultValue: "Good morning, \("Maria")")
                        .localized(in: locale))
                        .font(entry.font)
                        .foregroundStyle(Palette.ink)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
#endif
