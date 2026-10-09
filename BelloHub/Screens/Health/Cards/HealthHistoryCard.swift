//
//  HealthHistoryCard.swift
//  BelloHub
//

import SwiftUI

/// The answers of the latest health form, who gave them and when, and where the review stands. For a form filled in
/// for someone under 18 it says so, with the young person's name (D17).
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(verbatim: reportedByLine).font(Typography.footnote).foregroundStyle(Palette.ink2)
            Text(reviewEveryResource.localized(in: locale)).font(Typography.footnote).foregroundStyle(Palette.ink2)
            reviewStatusLine
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("health.review")
    }

    private var reviewEveryResource: LocalizedStringResource {
        let months = viewModel.reviewMonths
        return LocalizedStringResource("health.review.every", defaultValue: "Review every \(months) months")
    }

    @ViewBuilder
    private var reviewStatusLine: some View {
        let formatters = viewModel.formatters
        switch viewModel.reviewStatus {
        case .current(let dueAt)?:
            statusRow(
                chip: StatusChip(label: "health.review.upToDate", style: StatusPalette.confirmed),
                note: LocalizedStringResource(
                    "health.review.nextOn", defaultValue: "Next review on \(formatters.shortDate(dueAt))"
                )
            )
        case .due(let dueAt)?:
            statusRow(
                chip: StatusChip(label: "health.review.due", style: StatusPalette.attention),
                note: LocalizedStringResource(
                    "health.review.wasDueOn", defaultValue: "Was due on \(formatters.shortDate(dueAt))"
                )
            )
        case .undated?:
            Text("health.review.undated").font(Typography.footnote).foregroundStyle(Palette.ink2)
        case nil:
            EmptyView()
        }
    }

    /// The chip and the date beside it; at accessibility sizes they stack.
    private func statusRow(chip: StatusChip, note: LocalizedStringResource) -> some View {
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.xs) {
            chip
            Text(note.localized(in: locale)).font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
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
