//
//  RecordPendingAlertCards.swift
//  BelloHub
//

import SwiftUI

/// "Records to complete" in Alerts: every record still owed (`RecordPending`), one card each, with its action. A
/// completed booking with nothing written says "Register"; a draft says "Continue". Both open the visit form at once.
/// The same visit is never listed twice, here or between Home and Alerts.
struct RecordPendingAlertCards: View {
    let pending: RecordPending
    let clientNames: [UUID: String]
    let formatters: Formatters
    let now: Date
    let onOpen: (RecordPending.Item) -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        SectionHeader(title: "alerts.section.records").motionRow()
        ForEach(pending.items) { item in card(item).motionRow() }
    }

    private func card(_ item: RecordPending.Item) -> some View {
        let who = BidiIsolate.wrap(clientNames[item.clientID] ?? "")
        let service = BidiIsolate.wrap(item.serviceName)
        let day = formatters.recentDate(item.date, now: now)
        let isDraft = item.kind == .draft
        return AlertCard(
            icon: isDraft ? .compose : .document, tone: isDraft ? .rose : .peach,
            title: Text(isDraft ? "alerts.records.draft.title" : "alerts.records.unwritten.title"),
            message: Text(isDraft
                ? LocalizedStringResource(
                    "alerts.records.draft.message", defaultValue: "\(who) · \(service), started \(day)."
                ).localized(in: locale)
                : LocalizedStringResource(
                    "alerts.records.unwritten.message",
                    defaultValue: "\(who) · \(service), \(day). Nothing written yet."
                ).localized(in: locale)),
            identifier: "alerts.records.\(item.id)"
        ) {
            Button { onOpen(item) } label: {
                Text(isDraft ? "home.records.continue" : "home.records.register")
            }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("alerts.records.\(item.id).action")
        }
    }
}
