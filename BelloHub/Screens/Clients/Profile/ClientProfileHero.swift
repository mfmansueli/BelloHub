//
//  ClientProfileHero.swift
//  BelloHub
//

import SwiftUI

/// The one memorable card of the client record: her avatar, name and contact, the labels the vault gives her (tags,
/// "cancels often", no-shows, "online booking stopped") and three small actions: message, call and edit. A button
/// that cannot work (no phone number) is not shown.
struct ClientProfileHero: View {
    let client: Client
    let chips: [ClientProfileChip]
    let canCall: Bool
    let canMessage: Bool
    let onCall: () -> Void
    let onMessage: () -> Void
    let onEdit: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HeroCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Stacked at the accessibility sizes, where side by side would squeeze the name.
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.md))
                    : AnyLayout(HStackLayout(spacing: Spacing.md))
                layout {
                    Avatar(name: client.name, id: client.id.uuidString, size: 56).fixedAvatarText()
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(verbatim: client.name)
                            .font(Typography.title)
                            .foregroundStyle(HeroPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("clientProfile.name")
                        contact
                    }
                }
                if !chips.isEmpty {
                    FlowLayout {
                        ForEach(chips, id: \.self) { chip in HeroChip(chip: chip) }
                    }
                }
                actions
            }
        }
    }

    /// Her phone and e-mail, as she typed them. Numbers stay left to right inside a right-to-left language.
    @ViewBuilder
    private var contact: some View {
        let lines = [client.phoneE164, client.email].compactMap { $0 }.map(BidiIsolate.wrapLeftToRight)
        if !lines.isEmpty {
            Text(verbatim: lines.joined(separator: " · "))
                .font(Typography.meta)
                .foregroundStyle(HeroPalette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("clientProfile.contact")
        }
    }

    /// Message, call and edit, small and side by side: the record's main action is "Register visit" below.
    private var actions: some View {
        HStack(spacing: Spacing.md) {
            if canMessage {
                heroAction(icon: .chat, title: "clientProfile.message", identifier: "clientProfile.messageButton",
                           action: onMessage)
            }
            if canCall {
                heroAction(icon: .phone, title: "clientProfile.call", identifier: "clientProfile.callButton",
                           action: onCall)
            }
            heroAction(icon: .pencil, title: "clientProfile.edit", identifier: "clientProfile.editAction",
                       action: onEdit)
            Spacer(minLength: 0)
        }
    }

    private func heroAction(
        icon: Icon, title: LocalizedStringKey, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(icon: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(HeroPalette.ink)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(HeroPalette.raised, in: Circle())
                    .accessibilityHidden(true)
                Text(title)
                    .font(Typography.footnote)
                    .foregroundStyle(HeroPalette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(minWidth: 64, minHeight: Spacing.touchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

private struct HeroChip: View {
    let chip: ClientProfileChip
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Spacing.xs + Spacing.xxs) {
            if case .tag = chip {
                Circle().fill(Palette.rose).frame(width: 6, height: 6).accessibilityHidden(true)
            }
            text
                .font(Typography.caption)
                .foregroundStyle(HeroPalette.ink)
        }
        .padding(.horizontal, Spacing.row)
        .frame(minHeight: 28)
        .background(HeroPalette.raised, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var text: Text {
        switch chip {
        case .tag(let name):
            Text(verbatim: name)
        case .cancelsOften:
            Text("clientProfile.chip.cancelsOften")
        case .noShows(let count):
            Text(LocalizedStringResource("clientProfile.chip.noShows", defaultValue: "\(count) no-shows")
                .localized(in: locale))
        case .onlineBookingStopped:
            Text("clientProfile.chip.bookingStopped")
        case .archived:
            Text("clientProfile.chip.archived")
        }
    }
}
