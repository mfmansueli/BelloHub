//
//  WeekClockCard.swift
//  BelloHub
//

import SwiftUI

/// The week start and the clock of Language and region (7.2), two segmented pickers in one card. The region sets a
/// default for both; the card shows the effective value and the bindings record her override.
struct WeekClockCard: View {
    @Binding var firstWeekday: Int
    @Binding var use24Hour: Bool

    @Environment(\.locale) private var locale

    var body: some View {
        ListCard(dividerInset: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("languageRegion.weekStart").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Picker(selection: $firstWeekday) {
                    ForEach(LanguageRegionRules.weekStartOptions, id: \.self) { weekday in
                        Text(verbatim: LocalePreview.weekdayName(weekday, locale: locale)).tag(weekday)
                    }
                } label: {
                    Text("languageRegion.weekStart")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("languageRegion.weekStartPicker")
            }
            .padding(Spacing.md)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("languageRegion.clock").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Picker(selection: $use24Hour) {
                    Text("languageRegion.clock.24").tag(true)
                    Text("languageRegion.clock.12").tag(false)
                } label: {
                    Text("languageRegion.clock")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("languageRegion.clockPicker")
            }
            .padding(Spacing.md)
        }
    }
}
