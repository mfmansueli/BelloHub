//
//  BookingLinkCard.swift
//  BelloHub
//

import SwiftUI

/// The dark card at the top of the booking page settings: her link, a line saying clients need nothing installed, and
/// Copy and Share. Before she chose an address it invites her to, and says the page is not online yet. The card is
/// the prototype's hero, with the hero palette's text colors, which are measured on its gradient.
struct BookingLinkCard<Destination: View>: View {
    let link: BookingLink?
    let shareMessage: String
    let isCopied: Bool
    let onCopy: () -> Void
    @ViewBuilder let chooseAddress: () -> Destination

    var body: some View {
        HeroCard {
            VStack(alignment: .leading, spacing: Spacing.row) {
                Text("bookingSettings.link.title")
                    .font(Typography.metaStrong).foregroundStyle(HeroPalette.ink2)
                if let link {
                    Text(verbatim: link.display)
                        .font(Typography.subtitle).foregroundStyle(HeroPalette.ink)
                        .environment(\.layoutDirection, .leftToRight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("bookingSettings.linkText")
                } else {
                    Text("bookingSettings.link.noAddress")
                        .font(Typography.subtitle).foregroundStyle(HeroPalette.ink)
                        .accessibilityIdentifier("bookingSettings.linkText")
                }
                Text("bookingSettings.link.subtitle").font(Typography.meta).foregroundStyle(HeroPalette.ink2)
                Text("bookingSettings.link.notOnline").font(Typography.metaStrong).foregroundStyle(HeroPalette.ink2)
                    .accessibilityIdentifier("bookingSettings.notOnline")
                buttons
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if let link {
            HStack(spacing: Spacing.row) {
                Button(action: onCopy) {
                    Text(isCopied ? "bookingSettings.link.copied" : "bookingSettings.link.copy")
                }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("bookingSettings.copyButton")
                ShareLink(item: link.url, message: Text(verbatim: shareMessage)) {
                    Label { Text("bookingSettings.link.share") } icon: { Image(icon: .share) }
                }
                .buttonStyle(.belloOnHero)
                .accessibilityIdentifier("bookingSettings.shareButton")
            }
        } else {
            chooseAddress()
                .buttonStyle(.belloOnHero)
                .accessibilityIdentifier("bookingSettings.chooseAddressButton")
        }
    }
}
