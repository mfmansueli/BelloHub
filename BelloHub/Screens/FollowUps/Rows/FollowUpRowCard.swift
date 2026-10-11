//
//  FollowUpRowCard.swift
//  BelloHub
//

import SwiftUI

/// One client in the follow-up queue (routine-a items 5, 6 and 12): her name, then every reason she is here, each with
/// why (in plain words), where its message stands and its actions. Several reasons of one client share the card, so
/// nothing is lost by grouping; the first is the most urgent.
struct FollowUpRowCard: View {
    let row: FollowUpQueue.Row
    let formatters: Formatters
    /// True in the "Set aside" section: each reason offers "Bring back" instead of its actions.
    var isSetAside = false
    let onAction: (FollowUpAction) -> Void
    let onBook: (UUID) -> Void
    let onMarkSent: (FollowUpItem) -> Void
    let onSnooze: (FollowUpItem) -> Void
    let onDismiss: (FollowUpItem) -> Void
    let onRestore: (FollowUpItem) -> Void
    let onFinishClosing: (FollowUpItem) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var text: FollowUpReasonText { FollowUpReasonText(formatters: formatters) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.row) {
                Avatar(name: row.client.name, id: row.client.id.uuidString, size: 44)
                Text(verbatim: row.client.name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(Array(row.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().overlay(Palette.hairline) }
                itemView(item, isMain: index == 0)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("followUps.row.\(row.client.id.uuidString)")
    }

    // MARK: - One reason

    private func itemView(_ item: FollowUpItem, isMain: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(verbatim: text.why(item.reason))
                .font(Typography.meta).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("followUps.reason.\(item.occurrence)")
            if item.kind != .unfinishedVisit {
                Label { Text(verbatim: text.delivery(item.delivery)) } icon: { Image(icon: deliveryIcon(item)) }
                    .font(Typography.footnote).foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("followUps.delivery.\(item.occurrence)")
            }
            if isSetAside {
                Button { onRestore(item) } label: { Text("followUpQueue.action.restore") }
                    .buttonStyle(.belloChip(selected: false))
                    .accessibilityIdentifier("followUps.restore.\(item.occurrence)")
            } else {
                actions(item, isMain: isMain)
            }
        }
    }

    private func actions(_ item: FollowUpItem, isMain: Bool) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.sm))
        return layout {
            if let action = FollowUpAction.primary(for: item) {
                Button { onAction(action) } label: { Text(FollowUpAction.title(for: item.kind)) }
                    .buttonStyle(isMain ? .belloSecondary : .belloChip(selected: false))
                    .accessibilityIdentifier("followUps.action.\(item.occurrence)")
            }
            if FollowUpAction.offersMarkSent(item) {
                Button { onMarkSent(item) } label: { Text("followUpQueue.action.sent") }
                    .buttonStyle(.belloChip(selected: false))
                    .accessibilityIdentifier("followUps.sent.\(item.occurrence)")
            }
            if FollowUpAction.offersBooking(item) {
                Button { onBook(item.clientID) } label: { Text("followUpQueue.action.book") }
                    .buttonStyle(.belloChip(selected: false))
                    .accessibilityIdentifier("followUps.book.\(item.occurrence)")
            }
            menu(item)
        }
    }

    @ViewBuilder
    private func menu(_ item: FollowUpItem) -> some View {
        if item.kind.canBeSetAside || item.kind == .unfinishedVisit {
            Menu {
                if item.kind == .unfinishedVisit {
                    Button { onFinishClosing(item) } label: { Text("followUpQueue.action.finish") }
                } else {
                    Button { onSnooze(item) } label: { Text("followUpQueue.action.later") }
                    Button(role: .destructive) { onDismiss(item) } label: { Text("followUpQueue.action.dismiss") }
                }
            } label: {
                Image(icon: .more)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
            }
            .accessibilityLabel(Text("followUpQueue.action.more"))
            .accessibilityIdentifier("followUps.menu.\(item.occurrence)")
        }
    }

    private func deliveryIcon(_ item: FollowUpItem) -> Icon {
        switch item.delivery {
        case .readyToSend: .chat
        case .conversationOpened: .clock
        case .markedSentByHer: .check
        }
    }
}
