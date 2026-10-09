//
//  WaitlistPersonRow.swift
//  BelloHub
//

import SwiftUI

/// One person on the waitlist: name, when they asked and for what, and Offer (or "Offered until …" once sent). A swipe
/// is not available inside a card, so Remove sits in the row's context menu and its VoiceOver actions.
struct WaitlistPersonRow: View {
    let entry: WaitlistRequest
    let formatters: Formatters
    let canOffer: Bool
    let isOffering: Bool
    let result: WaitlistViewModel.OfferResult?
    let onOffer: () -> Void
    let onRemove: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: entry.name, id: entry.id)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: entry.name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: detail).font(Typography.meta).foregroundStyle(Palette.ink2)
                if let status { Text(status).font(Typography.metaStrong).foregroundStyle(Palette.sageText) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("waitlist.person.\(entry.id)")
            Spacer(minLength: Spacing.sm)
            if isOffering {
                ProgressView().frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
            } else if canOffer, entry.isWaiting, result == nil {
                Button(action: onOffer) { Text("waitlist.offer") }
                    .buttonStyle(.belloChip(selected: false))
                    .fixedSize()
                    .accessibilityIdentifier("waitlist.offer.\(entry.id)")
            }
        }
        .padding(Spacing.md)
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label("waitlist.remove", systemImage: Icon.trash.symbolName)
            }
        }
        .accessibilityAction(named: Text("waitlist.remove"), onRemove)
    }

    private var detail: String {
        let asked = String(localized: LocalizedStringResource(
            "waitlist.asked", defaultValue: "Asked \(formatters.dayMonth(entry.createdAt))"
        ).localized(in: locale))
        guard let service = entry.serviceName, !service.isEmpty else { return asked }
        return "\(asked) · \(service)"
    }

    private var status: LocalizedStringResource? {
        switch result {
        case .offered(let until)?:
            LocalizedStringResource(
                "waitlist.offeredUntil",
                defaultValue: "Offered until \(BidiIsolate.wrapLeftToRight(formatters.time(until)))"
            ).localized(in: locale)
        case .slotTaken?:
            nil
        case nil:
            entry.status == .offered ? LocalizedStringResource("waitlist.offered").localized(in: locale) : nil
        }
    }
}
