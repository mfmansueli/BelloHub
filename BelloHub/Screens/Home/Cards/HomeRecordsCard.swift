//
//  HomeRecordsCard.swift
//  BelloHub
//

import SwiftUI

/// "To follow up" on Home: the records still owed (`RecordPending`), newest first, each one tap from the visit form:
/// a completed booking with nothing written opens a new record linked to it, a draft opens itself. Three at most;
/// the rest wait in Alerts, where the full list lives.
struct HomeRecordsCard: View {
    let pending: RecordPending
    let clientNames: [UUID: String]
    let formatters: Formatters
    let now: Date
    let onOpen: (RecordPending.Item) -> Void
    let onSeeAll: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("home.records.title")
                .font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Spacing.row)
            ListCard(dividerInset: 72) {
                ForEach(pending.items.prefix(HomeBlockIDs.recordsShown)) { item in
                    Button { onOpen(item) } label: { row(item) }
                        .buttonStyle(.plain)
                        .accessibilityHint(
                            Text(item.kind == .draft ? "home.records.continue.hint" : "home.records.register.hint")
                        )
                        .accessibilityIdentifier("home.records.\(item.id)")
                        .motionRow()
                }
                if pending.items.count > HomeBlockIDs.recordsShown {
                    Button(action: onSeeAll) {
                        HomeCountRow(icon: .bell, tone: .sage, title: Text("home.records.seeAll"),
                                     count: formatters.number(pending.items.count))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.records.seeAll")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.records")
    }

    private func row(_ item: RecordPending.Item) -> some View {
        HomeCountRow(
            icon: item.kind == .draft ? .compose : .document,
            tone: item.kind == .draft ? .rose : .peach,
            title: Text(verbatim: clientNames[item.clientID] ?? ""),
            subtitle: Text(verbatim: subtitle(item))
        )
    }

    /// "Record pending · Glow facial · Yesterday": the state first, so the list reads at a glance.
    private func subtitle(_ item: RecordPending.Item) -> String {
        let state = item.kind == .draft
            ? LocalizedStringResource("record.status.draft").resolved(in: locale)
            : LocalizedStringResource("clientRecord.pending.title").resolved(in: locale)
        return [state, item.serviceName, formatters.recentDate(item.date, now: now)]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
