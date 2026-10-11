//
//  ShareFallbackCard.swift
//  BelloHub
//

import SwiftUI

/// When neither WhatsApp nor Messages could open, the message is still one tap from leaving: the system share sheet
/// (copy, mail, any app she has). Shown in place of "it is ready in WhatsApp", never as a surprise popup.
struct ShareFallbackCard: View {
    let text: String
    var identifier = "message.shareFallback"

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            Text("appointment.share.title")
                .font(Typography.bodyStrong)
                .foregroundStyle(Palette.amberText)
            Text("appointment.share.message")
                .font(Typography.meta)
                .foregroundStyle(Palette.amberText)
            ShareLink(item: text) {
                Label { Text("appointment.share.button") } icon: { Image(icon: .share) }
            }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("\(identifier).shareButton")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.amberBg, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}
