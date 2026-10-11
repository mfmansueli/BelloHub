//
//  ImportSourceRow.swift
//  BelloHub
//

import SwiftUI

/// One way to bring clients in: an icon tile, a title and a line under it. A row with no action is not available yet
/// ("Other booking apps, Coming soon"): it is drawn quiet and is not a button, so VoiceOver reads it as plain text
/// instead of a control that does nothing.
struct ImportSourceRow: View {
    enum Tone {
        case sand
        case sage
        case neutral

        fileprivate var fill: Color {
            switch self {
            case .sand: Palette.neutralWash
            case .sage: Palette.sageWash
            case .neutral: Palette.sunken
            }
        }

        fileprivate var symbol: Color {
            switch self {
            case .sand: Palette.neutralText
            case .sage: Palette.sageText
            case .neutral: Palette.ink2
            }
        }
    }

    let icon: Icon
    let tone: Tone
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let identifier: String
    /// Nil for a source that does not exist yet.
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifier)
        } else {
            content
                .accessibilityIdentifier(identifier)
        }
    }

    private var content: some View {
        HStack(spacing: Spacing.row) {
            Image(icon: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tone.symbol)
                .frame(width: 44, height: 44)
                .background(tone.fill, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(Typography.bodyStrong).foregroundStyle(action == nil ? Palette.ink2 : Palette.ink)
                Text(subtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: Spacing.sm)
            if action != nil {
                Image(icon: .forward)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
                    .flipsForRightToLeftLayoutDirection(true)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
