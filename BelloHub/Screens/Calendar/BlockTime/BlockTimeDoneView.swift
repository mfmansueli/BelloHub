//
//  BlockTimeDoneView.swift
//  BelloHub
//

import SwiftUI

/// What the Block time sheet shows once the time is closed: a seal, the clients whose visits were cancelled (each
/// with a way to tell them), and a notice for visits that were kept or could not be cancelled.
struct BlockTimeDoneView: View {
    let outcome: BlockTimeViewModel.Outcome
    let formatters: Formatters
    let clientName: (Appointment) -> String
    let onMessage: (UUID) -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                SuccessSeal(size: 72).padding(.top, Spacing.lg)
                Text("blockTime.done.title")
                    .font(Typography.title).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("blockTime.done")
                if outcome.failedCancellations > 0 {
                    InlineNotice(style: .warning, title: "blockTime.done.failed.title",
                                 message: "blockTime.done.failed.message")
                        .accessibilityIdentifier("blockTime.done.failed")
                }
                if !outcome.cancelled.isEmpty { cancelledList }
                if !outcome.kept.isEmpty {
                    InlineNotice(style: .info, title: "blockTime.done.kept.title",
                                 message: "blockTime.done.kept.message")
                        .accessibilityIdentifier("blockTime.done.kept")
                }
                Button(action: onBack) { Text("blockTime.done.back") }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("blockTime.done.backButton")
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.lg)
        }
    }

    private var cancelledList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "blockTime.done.section")
            Text("blockTime.done.note")
                .font(Typography.meta).foregroundStyle(Palette.ink2).padding(.bottom, Spacing.sm)
            VStack(spacing: 0) {
                ForEach(Array(outcome.cancelled.enumerated()), id: \.element.id) { index, visit in
                    if index > 0 { Divider().overlay(Palette.hairline) }
                    row(visit, index: index)
                }
            }
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        }
    }

    private func row(_ visit: Appointment, index: Int) -> some View {
        Button { onMessage(visit.id) } label: {
            HStack(spacing: Spacing.row) {
                Avatar(name: clientName(visit), id: visit.clientID.uuidString, size: 40)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: clientName(visit))
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(verbatim: formatters.dateTime(visit.startsAt))
                        .font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: Spacing.sm)
                Text("blockTime.done.message")
                    .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("blockTime.done.messageButton.\(index)")
    }
}
