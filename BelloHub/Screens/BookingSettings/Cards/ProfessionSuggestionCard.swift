//
//  ProfessionSuggestionCard.swift
//  BelloHub
//

import SwiftUI

/// "Suggested for: Hair" (routine item 10): the time between clients and start times that suit her profession
/// (`ProfessionAgendaDefaults`), shown only while hers differ, with "Use these". Nothing changes until she taps it, and
/// her hours, notice and window stay hers.
struct ProfessionSuggestionCard: View {
    let professionName: String?
    let defaults: ProfessionAgendaDefaults
    let formatters: Formatters
    let onUse: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                title.font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                line("bookingSettings.rules.buffer", value: formatters.minutes(defaults.bufferMinutes))
                line("bookingSettings.rules.slotStep", value: stepText)
                line("bookingSettings.rules.compact", value: LocalizedStringResource("bookingSettings.suggestion.on")
                    .resolved(in: locale))
                Text("bookingSettings.suggestion.note").font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
            .accessibilityElement(children: .combine)
            Button(action: onUse) { Text("bookingSettings.suggestion.use") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("bookingSettings.suggestion.useButton")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
    }

    // MARK: - Parts

    private var title: Text {
        guard let professionName else { return Text("bookingSettings.suggestion.titleGeneric") }
        return Text(LocalizedStringResource(
            "bookingSettings.suggestion.title", defaultValue: "Suggested for: \(professionName)"
        ).localized(in: locale))
    }

    private func line(_ label: LocalizedStringResource, value: String) -> some View {
        Text(LocalizedStringResource(
            "bookingSettings.suggestion.line", defaultValue: "\(label.resolved(in: locale)): \(value)"
        ).localized(in: locale))
            .font(Typography.meta).foregroundStyle(Palette.ink2)
    }

    private var stepText: String {
        LocalizedStringResource(
            "bookingSettings.slotStep.every", defaultValue: "Every \(defaults.slotStepMinutes) min"
        ).resolved(in: locale)
    }
}
