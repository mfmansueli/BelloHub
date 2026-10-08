//
//  InsightTile.swift
//  BelloHub
//

import SwiftUI

/// A tinted tile with an icon disc, a Fraunces numeral and a label. The whole tile is one
/// accessibility element and one tap target. The numeral is capped before the accessibility sizes,
/// where the label wraps instead.
struct InsightTile: View {
    enum Tone {
        case sage
        case rose
        case peach

        fileprivate var wash: Color {
            switch self {
            case .sage: Palette.sageWash
            case .rose: Palette.roseWash
            case .peach: Palette.peachWash
            }
        }

        fileprivate var accent: Color {
            switch self {
            case .sage: Palette.sageText
            case .rose: Palette.roseDeepText
            case .peach: Palette.peachText
            }
        }
    }

    let icon: Icon
    let value: String
    let label: LocalizedStringKey
    var tone: Tone = .sage

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(icon: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tone.accent)
                .frame(width: 36, height: 36)
                .background(Palette.surface, in: Circle())
                .accessibilityHidden(true)
            Text(verbatim: value)
                .font(.custom(FontRegistry.serifFamily, size: 30, relativeTo: .title).weight(.medium))
                .foregroundStyle(Palette.ink)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .contentTransition(.numericText())
            Text(label)
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
        }
        // Fills the row's height so tiles side by side stay equal when one label wraps to two lines
        // (the row is a `HStack` with `.fixedSize(horizontal: false, vertical: true)`).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.md)
        .background(tone.wash, in: RoundedRectangle(cornerRadius: Radius.tileSmall, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
