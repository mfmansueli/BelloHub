//
//  InlineNotice.swift
//  BelloHub
//

import SwiftUI

/// A tinted card inside a screen: `.safety` (coral: allergies, contraindications, reactions),
/// `.info` (sage) or `.warning` (amber). The icon is decorative; the title carries the meaning.
struct InlineNotice: View {
    enum Style {
        case safety
        case info
        case warning

        fileprivate var icon: Icon {
            switch self {
            case .safety, .warning: .alert
            case .info: .info
            }
        }

        fileprivate var foreground: Color {
            switch self {
            case .safety: Palette.coralText
            case .info: Palette.sageText
            case .warning: Palette.amberText
            }
        }

        fileprivate var background: Color {
            switch self {
            case .safety: Palette.coralBg
            case .info: Palette.sageWash
            case .warning: Palette.amberBg
            }
        }
    }

    let style: Style
    let title: LocalizedStringKey
    var message: LocalizedStringKey?

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.row) {
            Image(icon: style.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(style.foreground)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title).font(Typography.bodyStrong).foregroundStyle(style.foreground)
                if let message {
                    Text(message).font(Typography.meta).foregroundStyle(style.foreground)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(style.background, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
