//
//  TimeZoneNoticeCard.swift
//  BelloHub
//

import SwiftUI

/// Home's time-zone card: what differs, what follows the business zone, and three choices. A surface card rather than
/// an `InlineNotice`, because `InlineNotice` carries no actions and its tinted fills were never measured against the
/// tertiary button ink; on `surface` every pair here is one the contrast tests already measure.
struct TimeZoneNoticeCard: View {
    let text: TimeZoneNoticeText
    let showsRegionNote: Bool
    let isSaving: Bool
    let errorMessage: String?
    let onUsePhoneZone: () -> Void
    let onKeep: () -> Void
    let onLanguageRegion: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            message
            usePhoneButton
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) { secondaryButtons }
                VStack(alignment: .leading, spacing: Spacing.xs) { secondaryButtons }
            }
            if let errorMessage {
                ErrorNotice(message: errorMessage).accessibilityIdentifier("home.timeZoneNotice.error")
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.timeZoneNotice")
    }

    // MARK: - Sections

    /// One spoken element: both zones, the difference, what follows the business and the region note.
    private var message: some View {
        HStack(alignment: .top, spacing: Spacing.row) {
            Image(icon: .globe)
                .font(Typography.bodyStrong)
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(text.headline.localized(in: locale))
                    .font(Typography.bodyStrong)
                    .foregroundStyle(Palette.ink)
                Text(text.difference.localized(in: locale))
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
                Text("timeZoneNotice.follows")
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
                if showsRegionNote {
                    Text("timeZoneNotice.regionNote")
                        .font(Typography.meta)
                        .foregroundStyle(Palette.ink2)
                        .accessibilityIdentifier("home.timeZoneNotice.regionNote")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.timeZoneNotice.message")
    }

    private var usePhoneButton: some View {
        Button(action: onUsePhoneZone) {
            if isSaving {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text("timeZoneNotice.usePhone").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.belloSecondary)
        .disabled(isSaving)
        .accessibilityIdentifier("home.timeZoneNotice.usePhone")
    }

    @ViewBuilder
    private var secondaryButtons: some View {
        Button(action: onKeep) { Text("timeZoneNotice.keep") }
            .buttonStyle(.belloTertiary)
            .disabled(isSaving)
            .accessibilityIdentifier("home.timeZoneNotice.keep")
        Button(action: onLanguageRegion) { Text("timeZoneNotice.languageRegion") }
            .buttonStyle(.belloTertiary)
            .accessibilityIdentifier("home.timeZoneNotice.languageRegion")
    }
}

#if DEBUG
#Preview {
    let now = Date()
    let mismatch = TimeZoneMismatch.check(businessZoneID: "America/Sao_Paulo", phoneZoneID: "Europe/Rome", now: now)
    let formatters = Formatters(locale: Locale(identifier: "en_US"), timeZone: .current, currencyCode: "BRL")
    if let mismatch {
        TimeZoneNoticeCard(
            text: TimeZoneNoticeText(mismatch: mismatch, formatters: formatters, now: now), showsRegionNote: true,
            isSaving: false, errorMessage: nil, onUsePhoneZone: {}, onKeep: {}, onLanguageRegion: {}
        )
        .padding(Spacing.gutter)
        .background(Palette.bg)
    }
}
#endif
