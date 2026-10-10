//
//  HomeFollowUpsCard.swift
//  BelloHub
//

import SwiftUI

/// The follow-ups preview on Home: how many clients are ready to hear from her and the first three, with the link to
/// the full list (2.7). The message itself is written on that screen, so this card never offers a half-feature.
struct HomeFollowUpsCard: View {
    let digest: AgendaDigest
    /// How many, with what she calls the people she serves: "3 clients" (`ClientTerm.countText`).
    let counted: String
    let formatters: Formatters
    @Environment(\.locale) private var locale

    private static let previewCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringResource(
                "home.followUps.ready", defaultValue: "Ready to hear from you: \(BidiIsolate.wrap(counted))"
            ).localized(in: locale))
                .font(Typography.meta).foregroundStyle(Palette.ink2)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("home.followUps.summary")
            ForEach(digest.followUps.prefix(Self.previewCount)) { followUp in
                if let client = digest.client(followUp.clientID) {
                    Rectangle().fill(Palette.hairline).frame(height: 1).accessibilityHidden(true)
                    row(client: client, followUp: followUp)
                }
            }
            Rectangle().fill(Palette.hairline).frame(height: 1).accessibilityHidden(true)
            NavigationLink(value: AgendaRoute.followUps) {
                HStack {
                    Text("home.followUps.view")
                        .font(Typography.bodyStrong).foregroundStyle(Palette.roseText)
                    Spacer(minLength: Spacing.sm)
                    Image(icon: .forward).font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ink3).accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.followUps.view")
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .belloCard()
    }

    private func row(client: Client, followUp: FollowUp) -> some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: client.name, id: client.id.uuidString, size: 40)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: "\(client.firstName) · \(followUp.serviceName)")
                    .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(verbatim: formatters.daysAgo(followUp.daysSinceLastVisit))
                    .font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.row)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.followUps.row.\(client.id.uuidString)")
    }
}
