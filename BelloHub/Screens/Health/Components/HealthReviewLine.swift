//
//  HealthReviewLine.swift
//  BelloHub
//

import SwiftUI

/// "Review every 12 months" and where the review stands ("Up to date · Next review on Mar 3"), counted from the last
/// health form she keeps for the client. Says nothing until there is a dated one.
struct HealthReviewLine: View {
    let months: Int
    let status: HealthReviewStatus?
    let formatters: Formatters
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(LocalizedStringResource("health.review.every", defaultValue: "Review every \(months) months")
                .localized(in: locale))
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
            statusLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("health.review")
    }

    @ViewBuilder
    private var statusLine: some View {
        switch status {
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

    /// The chip and the date beside it; they wrap when the line is too narrow.
    private func statusRow(chip: StatusChip, note: LocalizedStringResource) -> some View {
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.xs) {
            chip
            Text(note.localized(in: locale)).font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }
}
