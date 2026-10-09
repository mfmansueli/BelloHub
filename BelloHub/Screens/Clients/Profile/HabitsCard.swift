//
//  HabitsCard.swift
//  BelloHub
//

import SwiftUI

/// "Habits": what the professional's own history says about this client, in neutral words (D13). Private to her, and
/// labelled so. Every number comes from `HabitsCalculator`; a row whose value is not known yet is left out.
struct HabitsCard: View {
    let habits: ClientHabits
    let source: ClientSource
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ListCard(dividerInset: Spacing.md) {
            row("clientProfile.habits.visits", value: Text(verbatim: habits.visits.formatted(.number.locale(locale))))
            row("clientProfile.habits.cancelled", value: count(habits.cancelled))
            row("clientProfile.habits.noShows", value: count(habits.noShows))
            row("clientProfile.habits.lateCancellations", value: count(habits.lateCancellations))
            if let weeks = habits.returnsEveryWeeks {
                row("clientProfile.habits.comesBack", value: Text(LocalizedStringResource(
                    "clientProfile.habits.everyWeeks", defaultValue: "Every ~\(weeks) weeks"
                ).localized(in: locale)))
            }
            if let period = habits.usualPeriod {
                row("clientProfile.habits.usuallyBooks", value: Text(period.title))
            }
            if let service = habits.mostBookedService {
                row("clientProfile.habits.mostBooked", value: Text(verbatim: service))
            }
            row("clientProfile.habits.foundYouVia", value: Text(source.title))
        }
        .accessibilityIdentifier("clientProfile.habits")
    }

    private func count(_ value: Int) -> Text {
        Text(verbatim: value.formatted(.number.locale(locale)))
    }

    /// Label and value side by side; stacked at the accessibility sizes, where two columns would squeeze both.
    private func row(_ label: LocalizedStringKey, value: Text) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xxs) { labelText(label); valueText(value) }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    labelText(label)
                    Spacer(minLength: Spacing.sm)
                    valueText(value).multilineTextAlignment(.trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    private func labelText(_ label: LocalizedStringKey) -> some View {
        Text(label).font(Typography.body).foregroundStyle(Palette.ink2)
    }

    private func valueText(_ value: Text) -> some View {
        value.font(Typography.bodyStrong).foregroundStyle(Palette.ink)
    }
}
