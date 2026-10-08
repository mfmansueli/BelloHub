//
//  CatalogButtonsSection.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// Button variants, chips and status chips.
struct CatalogButtonsSection: View {
    @State private var selectedChip = 0
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogSection(title: "Buttons and chips", identifier: "catalog.section.buttons") {
            Button {} label: { Text("catalog.sample.primary") }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("catalog.button.primary")
            Button {} label: { Text("catalog.sample.secondary") }.buttonStyle(.belloSecondary)
            Button {} label: {
                Text(LocalizedStringResource("catalog.sample.tertiary", defaultValue: "Running late? Tell \("Camila")")
                    .localized(in: locale))
            }
            .buttonStyle(.belloTertiary)
            Button {} label: { Text("catalog.sample.destructive") }.buttonStyle(.belloDestructive)
            Button {} label: { Text("catalog.sample.primary") }.buttonStyle(.belloPrimary).disabled(true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    chip("catalog.sample.filterAll", index: 0)
                    chip("catalog.sample.filterDue", index: 1)
                    chip("catalog.sample.nextUp", index: 2)
                }
            }
            HStack(spacing: Spacing.sm) {
                StatusChip(label: "catalog.sample.confirmed", style: StatusPalette.confirmed)
                StatusChip(label: "catalog.sample.pending", style: StatusPalette.pending)
            }
            HStack(spacing: Spacing.sm) {
                StatusChip(label: "catalog.sample.nextUp", style: StatusPalette.nextUp)
                StatusChip(label: "catalog.sample.completed", style: StatusPalette.completed)
                StatusChip(label: "catalog.sample.attention", style: StatusPalette.attention)
            }
        }
    }

    private func chip(_ key: LocalizedStringKey, index: Int) -> some View {
        Button { selectedChip = index } label: { Text(key) }
            .buttonStyle(.belloChip(selected: selectedChip == index))
            .accessibilityIdentifier("catalog.chip.\(index)")
    }
}
#endif
