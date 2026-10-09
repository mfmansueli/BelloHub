//
//  ClientRow.swift
//  BelloHub
//

import SwiftUI

/// One client in the list: avatar, name, when she was last seen (or what is booked) and one word at the end. Reads as
/// one VoiceOver element: "Ana Costa, Glow Facial, Aug 30, Sensitive skin". At the accessibility text sizes the word
/// moves under the name instead of squeezing it.
struct ClientRow: View {
    let entry: ClientListEntry
    let badge: ClientRowBadge
    let formatters: Formatters
    let now: Date

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: entry.client.name, id: entry.client.id.uuidString, size: 48).fixedAvatarText()
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    texts
                    badgeView
                }
            } else {
                texts
                Spacer(minLength: Spacing.sm)
                badgeView
            }
        }
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: Spacing.touchTarget)
        .accessibilityElement(children: .combine)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: entry.client.name)
                .font(Typography.bodyStrong)
                .foregroundStyle(Palette.ink)
            if let summary {
                Text(summary)
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
            }
        }
        // Why: the name and the date come first; a long tag may wrap, but never squeezes them.
        .layoutPriority(1)
    }

    @ViewBuilder
    private var badgeView: some View {
        switch badge {
        case .cancelsOften:
            badgeLabel(Text("clients.badge.cancelsOften"), color: Palette.coralText, dot: Palette.coralText)
        case .new:
            badgeLabel(Text("clients.badge.new"), color: Palette.roseText, dot: Palette.rose)
        case .tag(let name):
            badgeLabel(Text(verbatim: name), color: Palette.ink2, dot: nil)
        case .none:
            EmptyView()
        }
    }

    private func badgeLabel(_ text: Text, color: Color, dot: Color?) -> some View {
        HStack(spacing: Spacing.xs + Spacing.xxs) {
            if let dot {
                Circle().fill(dot).frame(width: 6, height: 6).accessibilityHidden(true)
            }
            text.font(Typography.footnoteStrong).foregroundStyle(color)
        }
    }

    /// "Glow Facial · Aug 30", or "Booked for Oct 1 · Brazilian Glow", or nothing for someone not seen yet.
    private var summary: LocalizedStringResource? {
        switch entry.summary {
        case .lastVisit(let service, let date):
            let day = formatters.recentDate(date, now: now)
            return LocalizedStringResource(
                "clients.row.lastVisit", defaultValue: "\(BidiIsolate.wrap(service)) · \(day)"
            ).localized(in: locale)
        case .booked(let service, let date):
            let day = formatters.recentDate(date, now: now)
            return LocalizedStringResource(
                "clients.row.booked", defaultValue: "Booked for \(day) · \(BidiIsolate.wrap(service))"
            ).localized(in: locale)
        case .noVisitsYet:
            return nil
        }
    }
}
