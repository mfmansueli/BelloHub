//
//  CatalogSection.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// A titled block of the catalog.
struct CatalogSection<Content: View>: View {
    let title: String
    /// Identifier of the section's title. Never put an identifier on the container: SwiftUI pushes it down to the
    /// children and replaces their own (a Button inside would lose `catalog.button.primary`).
    let identifier: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(verbatim: title)
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
