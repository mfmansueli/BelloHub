//
//  HomeWinBackLink.swift
//  BelloHub
//

import SwiftUI

/// "3 clients have not been back in 2+ months", a peach strip on Home that opens Win back (2.8). It uses the same
/// wording as the Clients list strip, so the two read alike.
struct HomeWinBackLink: View {
    let count: Int
    let noun: String
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.row))
    }

    var body: some View {
        NavigationLink(value: AgendaRoute.winBack) {
            layout {
                Image(icon: .repeatArrows)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.peachText)
                    .accessibilityHidden(true)
                Text(LocalizedStringResource(
                    "clients.winBack",
                    defaultValue: "\(count) \(BidiIsolate.wrap(noun)) have not been back in 2+ months"
                ).localized(in: locale))
                    .font(Typography.meta)
                    .foregroundStyle(Palette.peachText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(icon: .forward).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.peachText).accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(minHeight: Spacing.touchTarget)
            .background(Palette.peachWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.winBack")
    }
}
