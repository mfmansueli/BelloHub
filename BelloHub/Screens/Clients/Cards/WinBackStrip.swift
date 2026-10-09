//
//  WinBackStrip.swift
//  BelloHub
//

import SwiftUI

/// "3 clients have not been back in 2+ months". Informational: the Win back screen (2.8) arrives with the calendar
/// stage, and a strip that looks tappable and does nothing would be a dead end, so it is plain text for now.
struct WinBackStrip: View {
    let count: Int
    /// What she calls the people she serves, for several of them or one: "clients", "patients".
    let noun: String
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    /// At accessibility sizes the icon goes above the text: beside it, the text got a column 240 pt wide and the strip
    /// grew past 400 pt, pushing the first client out of the screen (found by the AX5 audit in German).
    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.row))
    }

    var body: some View {
        layout {
            Image(icon: .repeatArrows)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.peachText)
                .accessibilityHidden(true)
            Text(LocalizedStringResource(
                "clients.winBack", defaultValue: "\(count) \(BidiIsolate.wrap(noun)) have not been back in 2+ months"
            ).localized(in: locale))
                .font(Typography.meta)
                .foregroundStyle(Palette.peachText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.md)
        .background(Palette.peachWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .padding(.horizontal, Spacing.gutter)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("clients.winBack")
    }
}

#Preview {
    WinBackStrip(count: 3, noun: "clients")
}
