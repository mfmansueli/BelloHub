//
//  RecordHistoryCard.swift
//  BelloHub
//

import SwiftUI

/// One treatment record on 4.7: the visit, where it stands against the 24-hour lock, its edit trail and the one button
/// that changes it (Edit while it is open, Add correction once it is locked).
struct RecordHistoryCard: View {
    let item: RecordHistoryItem
    let formatters: Formatters
    let professionalName: String
    let onChange: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(item.trail.enumerated()), id: \.element.id) { index, entry in
                    RecordTrailRow(
                        entry: entry, formatters: formatters, professionalName: professionalName,
                        isLast: index == item.trail.count - 1
                    )
                }
            }
            Button(action: onChange) {
                Label {
                    Text(item.isLocked ? "recordHistory.addCorrection" : "recordHistory.edit")
                } icon: {
                    Image(icon: item.isLocked ? .plus : .pencil)
                }
            }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("recordHistory.change.\(item.id.uuidString)")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordHistory.record.\(item.id.uuidString)")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: item.record.serviceName)
                    .font(Typography.section).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: formatters.shortDate(item.record.createdAt))
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                if let remaining = item.remaining {
                    let time = formatters.remaining(remaining)
                    Text(LocalizedStringResource("recordHistory.lock.remaining", defaultValue: "Locks in \(time)")
                        .localized(in: locale))
                        .font(Typography.meta).foregroundStyle(Palette.amberText)
                        .accessibilityIdentifier("recordHistory.remaining.\(item.id.uuidString)")
                }
            }
            Spacer(minLength: Spacing.sm)
            lockChip
        }
    }

    @ViewBuilder
    private var lockChip: some View {
        if item.isLocked {
            StatusChip(label: "recordHistory.lock.locked", style: StatusPalette.confirmed)
                .accessibilityIdentifier("recordHistory.lock.\(item.id.uuidString)")
        } else {
            StatusChip(label: "recordHistory.lock.open", style: StatusPalette.pending)
                .accessibilityIdentifier("recordHistory.lock.\(item.id.uuidString)")
        }
    }
}
