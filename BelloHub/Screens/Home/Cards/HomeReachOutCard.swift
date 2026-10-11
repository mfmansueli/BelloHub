//
//  HomeReachOutCard.swift
//  BelloHub
//

import SwiftUI

/// The one secondary card of Home (routine-a item 4): check-ins, returns, clients not back lately and birthdays in a
/// single summary that opens the follow-up queue. The first rows say why they are there, in the queue's own words.
struct HomeReachOutCard: View {
    let reachOut: HomeReachOut
    let formatters: Formatters

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("home.reachOut.title")
                .font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Spacing.xs)
            Text("home.reachOut.subtitle")
                .font(Typography.meta).foregroundStyle(Palette.ink2)
                .padding(.bottom, Spacing.row)
            ListCard(dividerInset: Spacing.md) {
                ForEach(reachOut.preview) { row in preview(row) }
                NavigationLink(value: AgendaRoute.followUps(.all)) {
                    HomeCountRow(
                        icon: .repeatArrows, tone: .peach, title: Text("home.reachOut.open"),
                        count: formatters.number(reachOut.count)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.reachOut.open")
            }
        }
        .accessibilityIdentifier("home.reachOut")
    }

    private func preview(_ row: FollowUpQueue.Row) -> some View {
        HStack(alignment: .top, spacing: Spacing.row) {
            Avatar(name: row.client.name, id: row.client.id.uuidString, size: 40)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: row.client.name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: FollowUpReasonText(formatters: formatters).why(row.primary.reason))
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.reachOut.row.\(row.client.id.uuidString)")
    }
}
