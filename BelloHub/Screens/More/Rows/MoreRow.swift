//
//  MoreRow.swift
//  BelloHub
//

import SwiftUI

/// One row of a More section: a tinted icon tile, a title, an optional line under it and, for a row that opens a
/// screen, a chevron. It is the label of a `NavigationLink` or a `Button`; the caller puts the identifier on that.
struct MoreRow: View {
    /// The tile's color pair, always a `Palette` wash with its matching deep text color (3:1 or more for the icon).
    enum Tint {
        case rose
        case sage
        case peach
        case neutral

        fileprivate var foreground: Color {
            switch self {
            case .rose: Palette.roseDeepText
            case .sage: Palette.sageText
            case .peach: Palette.peachText
            case .neutral: Palette.neutralText
            }
        }

        fileprivate var background: Color {
            switch self {
            case .rose: Palette.roseWash
            case .sage: Palette.sageWash
            case .peach: Palette.peachWash
            case .neutral: Palette.neutralWash
            }
        }
    }

    let icon: Icon
    var tint = Tint.rose
    let title: Text
    var subtitle: Text?
    var showsChevron = false

    var body: some View {
        HStack(spacing: Spacing.row) {
            Image(icon: icon)
                .foregroundStyle(tint.foreground)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                .background(tint.background, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                title.font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                if let subtitle {
                    subtitle.font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                Image(icon: .forward)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
