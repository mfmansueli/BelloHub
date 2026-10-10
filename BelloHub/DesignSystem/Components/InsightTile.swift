//
//  InsightTile.swift
//  BelloHub
//

import SwiftUI

/// A solid brand-card tile (sage, rose or peach fill) with an icon badge, a Fraunces numeral and a label. Text on the
/// fill is `onBrandCard`, never the global secondary gray. The whole tile is one
/// accessibility element and one tap target. The numeral is capped before the accessibility sizes,
/// where the label wraps instead.
struct InsightTile: View {
    enum Tone {
        case sage
        case rose
        case peach

        fileprivate var fill: Color {
            switch self {
            case .sage: Palette.sageFill
            case .rose: Palette.roseFill
            case .peach: Palette.peachFill
            }
        }

        fileprivate var badge: Color {
            switch self {
            case .sage: Palette.sageBadge
            case .rose: Palette.roseBadge
            case .peach: Palette.peachBadge
            }
        }

        fileprivate var accent: Color {
            switch self {
            case .sage: Palette.sageText
            case .rose: Palette.roseText
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
                .background(tone.badge, in: Circle())
                .accessibilityHidden(true)
            Text(verbatim: value)
                .font(.custom(FontRegistry.serifFamily, size: 30, relativeTo: .title).weight(.medium))
                .foregroundStyle(Palette.onBrandCard)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .contentTransition(.numericText())
            Text(label)
                .font(Typography.footnote)
                .foregroundStyle(Palette.onBrandCard)
        }
        // Fills the row's height so tiles side by side stay equal when one label wraps to two lines
        // (the row is a `HStack` with `.fixedSize(horizontal: false, vertical: true)`).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.md)
        .background(tone.fill, in: RoundedRectangle(cornerRadius: Radius.tileSmall, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
