//
//  RequestOutcomeNotice.swift
//  BelloHub
//

import SwiftUI

/// What became of a request once she answered (2.10, 2.11): on its way, accepted, declined or withdrawn. The texts of
/// "accepted" and "declined" are the screen's, because a booking and a reschedule end differently.
struct RequestOutcomeNotice: View {
    let phase: InboxRequestPhase
    let acceptedText: LocalizedStringKey
    let declinedText: LocalizedStringKey
    let isWaitingForNetwork: Bool
    let identifier: String

    var body: some View {
        Group {
            switch phase {
            case .sending:
                HStack(spacing: Spacing.row) {
                    ProgressView()
                    Text(isWaitingForNetwork ? "inbox.sending.offline" : "inbox.sending")
                        .font(Typography.body).foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .belloCard(cornerRadius: Radius.tile)
                .accessibilityElement(children: .combine)
            case .accepted:
                InlineNotice(style: .info, title: acceptedText)
            case .declined:
                InlineNotice(style: .info, title: declinedText)
            case .withdrawn:
                InlineNotice(style: .warning, title: "inbox.withdrawn")
            default:
                EmptyView()
            }
        }
        .accessibilityIdentifier(identifier)
    }
}
