//
//  ServiceBadge.swift
//  BelloHub
//

import SwiftUI

/// A small word under a service's name ("Follow-up 4 weeks", "Photos", "Patch test"). Not a button: it states a setting
/// of the service. Always a word, never color alone; the three styles use text-on-wash pairs the palette tests measure.
struct ServiceBadge: View {
    enum Style {
        /// A setting that is on.
        case neutral
        /// Something the service warns about.
        case caution
        /// The service is switched off.
        case inactive

        fileprivate var foreground: Color {
            switch self {
            case .neutral: Palette.neutralText
            case .caution: Palette.coralText
            case .inactive: Palette.amberText
            }
        }

        fileprivate var background: Color {
            switch self {
            case .neutral: Palette.neutralWash
            case .caution: Palette.coralBg
            case .inactive: Palette.amberBg
            }
        }
    }

    let text: Text
    var style = Style.neutral

    var body: some View {
        text
            .font(Typography.footnoteStrong)
            .foregroundStyle(style.foreground)
            .padding(.horizontal, Spacing.row)
            .padding(.vertical, Spacing.xs + Spacing.xxs)
            .background(style.background, in: Capsule())
    }
}
