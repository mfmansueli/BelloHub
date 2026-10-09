//
//  ClientProfileHero.swift
//  BelloHub
//

import SwiftUI

/// The one memorable card of the profile: her avatar and name, the labels the vault gives her (tags, "cancels often",
/// no-shows, "online booking stopped") and the quick actions. Only Call exists in this stage: Message and Book are the
/// calendar stage's screens, and a button that does nothing is not shown.
struct ClientProfileHero: View {
    let client: Client
    let chips: [ClientProfileChip]
    let canCall: Bool
    let onCall: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HeroCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Stacked at the accessibility sizes, where side by side would squeeze the name.
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.md))
                    : AnyLayout(HStackLayout(spacing: Spacing.md))
                layout {
                    Avatar(name: client.name, id: client.id.uuidString, size: 72).fixedAvatarText()
                    Text(verbatim: client.name)
                        .font(Typography.title)
                        .foregroundStyle(HeroPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("clientProfile.name")
                }
                if !chips.isEmpty {
                    FlowLayout {
                        ForEach(chips, id: \.self) { chip in HeroChip(chip: chip) }
                    }
                }
                if canCall {
                    Button(action: onCall) {
                        VStack(spacing: Spacing.sm) {
                            Image(icon: .phone)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(HeroPalette.ink)
                                .frame(width: 56, height: 56)
                                .background(HeroPalette.raised, in: Circle())
                                .accessibilityHidden(true)
                            Text("clientProfile.call")
                                .font(Typography.meta)
                                .foregroundStyle(HeroPalette.ink)
                        }
                        .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("clientProfile.callButton")
                }
            }
        }
    }
}

/// A quiet label on the hero. Always a word; the dot only marks a tag.
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
