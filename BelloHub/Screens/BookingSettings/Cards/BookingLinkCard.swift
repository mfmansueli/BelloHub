//
//  BookingLinkCard.swift
//  BelloHub
//

import SwiftUI

/// The dark card at the top of the booking page settings: her link, a line saying clients need nothing installed, what
/// the link does right now (online, or only a preview until she goes online) and Copy and Share. Before she chose an
/// address it invites her to. The card is the prototype's hero, with the hero palette's text colors, which are measured
/// on its gradient.
struct BookingLinkCard<Destination: View>: View {
    let link: BookingLink?
    let shareMessage: String
    let isCopied: Bool
    let state: PublishState
    let onCopy: () -> Void
    let onGoOnline: () -> Void
    @ViewBuilder let chooseAddress: () -> Destination

    @Environment(\.locale) private var locale

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
                Text(PublishStatusText.linkStatus(state).localized(in: locale))
                    .font(Typography.metaStrong).foregroundStyle(HeroPalette.ink2)
                    .accessibilityIdentifier(statusIdentifier)
                buttons
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if let link {
            if !state.isLive { goOnlineButton }
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

    private var statusIdentifier: String {
        state.isLive ? "bookingSettings.onlineStatus" : "bookingSettings.notOnline"
    }

    private var isPublishing: Bool {
        if case .publishing = state { true } else { false }
    }

    private var goOnlineButton: some View {
        Button(action: onGoOnline) {
            if isPublishing {
                ProgressView()
            } else {
                Text("publish.action.goOnline")
            }
        }
        .buttonStyle(.belloOnHero)
        .disabled(isPublishing)
        .accessibilityIdentifier("bookingSettings.goOnlineButton")
    }
}
