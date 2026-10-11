//
//  HomeCountRow.swift
//  BelloHub
//

import SwiftUI

/// A row of Home's "Today" card and of its secondary cards: a tinted icon tile, a title, an optional line under it, a
/// count and a chevron. The label of a `Button` or `NavigationLink`; VoiceOver reads it as one element ("Reminders
/// ready to send, 3"). The count stands apart from the sentence so no plural has to be built.
struct HomeCountRow: View {
    enum Tone {
        case rose
        case sage
        case peach

        var foreground: Color {
            switch self {
            case .rose: Palette.roseDeepText
            case .sage: Palette.sageText
            case .peach: Palette.peachText
            }
        }

        var background: Color {
            switch self {
            case .rose: Palette.roseWash
            case .sage: Palette.sageWash
            case .peach: Palette.peachWash
            }
        }
    }

    let icon: Icon
    var tone = Tone.rose
    let title: Text
    var subtitle: Text?
    var count: String?

    var body: some View {
        HStack(spacing: Spacing.row) {
            Image(icon: icon)
                .foregroundStyle(tone.foreground)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                .background(tone.background, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                title.font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    subtitle.font(Typography.meta).foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let count {
                Text(verbatim: count)
                    .font(Typography.metaStrong)
                    .foregroundStyle(Palette.roseDeepText)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minWidth: 28, minHeight: 28)
                    .background(Palette.roseWash, in: Capsule())
                    .motionNumber(count)
            }
            Image(icon: .forward)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.ink3)
                .flipsForRightToLeftLayoutDirection(true)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ListCard(dividerInset: 72) {
        HomeCountRow(icon: .chat, title: Text(verbatim: "Reminders ready to send"), count: "3")
        HomeCountRow(icon: .calendar, tone: .sage, title: Text(verbatim: "Week at a glance"),
                     subtitle: Text(verbatim: "open slots"), count: "12")
    }
    .padding()
}
