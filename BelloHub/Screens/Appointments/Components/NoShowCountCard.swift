//
//  NoShowCountCard.swift
//  BelloHub
//

import SwiftUI

/// "Ana's count": how many misses count against a client, as dots, a number and one sentence about the rule, with a
/// link to change the rule. Used by the no-show sheet and the history, so both say the same.
struct NoShowCountCard<Destination: View>: View {
    let clientName: String
    let status: NoShowStatus
    let policy: NoShowPolicy
    var identifier = "noShowCount"
    @ViewBuilder let changeRule: () -> Destination
    @Environment(\.locale) private var locale

    private var message: NoShowCountMessage {
        NoShowCountMessage.make(status: status, policy: policy)
    }

    private var foreground: Color { message.isAlert ? Palette.coralText : Palette.ink }
    private var secondary: Color { message.isAlert ? Palette.coralText : Palette.ink2 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringResource("noShowCount.title", defaultValue: "\(clientName)'s count")
                    .localized(in: locale))
                    .font(Typography.metaStrong)
                    .foregroundStyle(secondary)
                Spacer(minLength: Spacing.sm)
                if status.isProtectionOn { dots }
            }
            if status.isProtectionOn {
                Text(LocalizedStringResource(
                    "noShowCount.value", defaultValue: "\(status.counted) of \(status.limit)"
                ).localized(in: locale))
                    .font(Typography.subtitle)
                    .foregroundStyle(foreground)
                    .accessibilityIdentifier("\(identifier).value")
            }
            sentence
                .font(Typography.meta)
                .foregroundStyle(secondary)
                .accessibilityIdentifier("\(identifier).sentence")
            NavigationLink(destination: changeRule) {
                Text("noShowCount.changeRule")
                    .font(Typography.metaStrong)
                    .foregroundStyle(message.isAlert ? Palette.coralText : Palette.roseText)
                    .frame(minHeight: Spacing.touchTarget, alignment: .leading)
            }
            .accessibilityIdentifier("\(identifier).changeRuleLink")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            message.isAlert ? Palette.coralBg : Palette.sunken,
            in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var dots: some View {
        HStack(spacing: Spacing.xs + Spacing.xxs) {
            ForEach(0..<status.limit, id: \.self) { index in
                Circle()
                    .fill(index < status.counted ? foreground : Color.clear)
                    .overlay { Circle().strokeBorder(foreground, lineWidth: 1.5) }
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityHidden(true)
    }

    private var sentence: Text {
        switch message {
        case .protectionOff:
            Text("noShowCount.off")
        case .counting(_, _, let remaining, let months):
            Text(verbatim: LocalizedStringResource(
                "noShowCount.counting", defaultValue: "Left before your limit: \(remaining)."
            ).resolved(in: locale) + " " + period(months))
        case .limitReached(let action, let months):
            Text(verbatim: reached(action) + " " + period(months))
        }
    }

    private func period(_ months: Int) -> String {
        LocalizedStringResource(
            "noShowCount.period", defaultValue: "Counted over the last \(months) months."
        ).resolved(in: locale)
    }

    private func reached(_ action: NoShowAction) -> String {
        let name = clientName
        switch action {
        case .tell:
            return LocalizedStringResource(
                "noShowCount.reached.tell", defaultValue: "\(name) reached your limit."
            ).resolved(in: locale)
        case .approveNewBookings:
            return LocalizedStringResource(
                "noShowCount.reached.approve",
                defaultValue: "\(name) reached your limit. From now on the online bookings need your approval."
            ).resolved(in: locale)
        case .pauseOnline:
            return LocalizedStringResource(
                "noShowCount.reached.pause",
                defaultValue: "\(name) reached your limit. From now on online booking is paused."
            ).resolved(in: locale)
        }
    }
}
