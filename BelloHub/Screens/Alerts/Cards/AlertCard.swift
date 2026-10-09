//
//  AlertCard.swift
//  BelloHub
//

import SwiftUI

/// One alert of the Alerts tab: a tinted icon, a title, a sentence and one action. The whole card is read as one
/// element for VoiceOver, with its action reachable inside it.
struct AlertCard<Action: View>: View {
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
    let tone: Tone
    let title: Text
    let message: Text
    /// On the combined text element, never on the card: the action inside keeps its own identifier.
    let identifier: String
    @ViewBuilder var action: Action

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            HStack(alignment: .top, spacing: Spacing.row) {
                Image(icon: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(tone.accent)
                    .frame(width: 36, height: 36)
                    .background(tone.wash, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    title.font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    message.font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
            action
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
    }
}
