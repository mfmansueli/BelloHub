//
//  CopyTextCard.swift
//  BelloHub
//

import SwiftUI

/// A text she pastes somewhere (an Instagram bio, a WhatsApp greeting): what it is for, the text as it will be pasted
/// and a Copy button that says "Copied" for a moment after it worked.
struct CopyTextCard: View {
    let icon: Icon
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let text: String
    let isCopied: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            HStack(alignment: .top, spacing: Spacing.row) {
                Image(icon: icon).foregroundStyle(Palette.roseDeepText)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(
                        Palette.roseWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    if let subtitle { Text(subtitle).font(Typography.meta).foregroundStyle(Palette.ink2) }
                }
            }
            Text(verbatim: text).font(Typography.body).foregroundStyle(Palette.ink)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            Button(action: action) {
                Text(isCopied ? "shareLink.copy.done" : "shareLink.copy.short")
            }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier(identifier)
        }
        .padding(Spacing.md)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
