//
//  HealthHistoryCard.swift
//  BelloHub
//

import SwiftUI

/// The answers of the latest health form answered in the app before D60, or sent from the booking page, and who gave
/// them and when. Read-only: new health forms are her own papers, kept in the folder above. For a form filled in for
/// someone under 18 it says so, with the young person's name (D17).
struct HealthHistoryCard: View {
    let viewModel: ClientHealthViewModel
    let form: HealthForm
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if form.isForMinor {
                InlineNotice(style: .info, title: "health.minor.title", message: "health.minor.message")
                    .accessibilityIdentifier("health.minorNotice")
            }
            ListCard(dividerInset: Spacing.md) {
                ForEach(viewModel.answerRows) { row in
                    HealthAnswerRow(
                        name: row.name, value: row.value, isAnswered: row.isAnswered,
                        identifier: "health.answer.\(row.key)"
                    )
                }
                if form.isForMinor {
                    HealthAnswerRow(
                        name: text("health.minor.name"), value: form.minorName ?? "", identifier: "health.minorName"
                    )
                }
                footer
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text(verbatim: reportedByLine)
            .font(Typography.footnote)
            .foregroundStyle(Palette.ink2)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("health.reportedBy")
    }

    /// "Reported by Ana · Sep 12", or "Filled in by you · Sep 12" when the professional filled it in herself.
    private var reportedByLine: String {
        let name = BidiIsolate.wrap(viewModel.clientFirstName)
        let date = form.signedAt.map { viewModel.formatters.shortDate($0) }
        let resource: LocalizedStringResource
        switch (form.filledBy, date) {
        case (.client, let date?):
            resource = LocalizedStringResource(
                "health.reportedBy.client", defaultValue: "Reported by \(name) · \(date)"
            )
        case (.client, nil):
            resource = LocalizedStringResource("health.reportedBy.clientUndated", defaultValue: "Reported by \(name)")
        case (.professional, let date?):
            resource = LocalizedStringResource(
                "health.reportedBy.professional", defaultValue: "Filled in by you · \(date)"
            )
        case (.professional, nil):
            resource = LocalizedStringResource(
                "health.reportedBy.professionalUndated", defaultValue: "Filled in by you"
            )
        }
        return String(localized: resource.localized(in: locale))
    }

    private func text(_ key: LocalizedStringResource) -> String {
        String(localized: key.localized(in: locale))
    }
}
