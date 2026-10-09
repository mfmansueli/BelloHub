//
//  ActionRow.swift
//  BelloHub
//

import SwiftUI

/// A card-sized row that does one thing: a tinted icon, a title, an optional line under it and, when it opens
/// something, a chevron. The profile's Health and consent, the new-client sheet's "Import many at once" and the edit
/// screen's Archive and Merge all use it, so they look and read the same. One element for VoiceOver.
struct ActionRow: View {
    enum Tone {
        case sage
        case peach
        case rose
        case coral

        fileprivate var wash: Color {
            switch self {
            case .sage: Palette.sageWash
            case .peach: Palette.peachWash
            case .rose: Palette.roseWash
            case .coral: Palette.coralBg
            }
        }

        fileprivate var ink: Color {
            switch self {
            case .sage: Palette.sageText
            case .peach: Palette.peachText
            case .rose: Palette.roseDeepText
            case .coral: Palette.coralText
            }
        }
    }

    let icon: Icon
    let title: Text
    var subtitle: Text?
    var tone: Tone = .rose
    var showsChevron = true
    let identifier: String
    let action: () -> Void

    init(
        icon: Icon, title: LocalizedStringKey, subtitle: Text? = nil, tone: Tone = .rose, showsChevron: Bool = true,
        identifier: String, action: @escaping () -> Void
    ) {
        self.init(
            icon: icon, title: Text(title), subtitle: subtitle, tone: tone, showsChevron: showsChevron,
            identifier: identifier, action: action
        )
    }

    /// For a title with an argument ("Archive client"), which a key cannot carry.
    init(
        icon: Icon, title: Text, subtitle: Text? = nil, tone: Tone = .rose, showsChevron: Bool = true,
        identifier: String, action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.showsChevron = showsChevron
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.row) {
                Image(icon: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tone.ink)
                    .frame(width: 44, height: 44)
                    .background(tone.wash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    title
                        .font(Typography.bodyStrong)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        subtitle
                            .font(Typography.meta)
                            .foregroundStyle(Palette.ink2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if showsChevron {
                    Image(icon: .forward)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink3)
                        .accessibilityHidden(true)
                }
            }
            .padding(Spacing.md)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .belloCard(cornerRadius: Radius.tileSmall)
        .accessibilityIdentifier(identifier)
    }
}

#Preview {
    ActionRow(
        icon: .download, title: "clients.import", subtitle: Text(verbatim: "From contacts or a spreadsheet"),
        tone: .peach, identifier: "preview.row", action: {}
    )
    .padding()
}
