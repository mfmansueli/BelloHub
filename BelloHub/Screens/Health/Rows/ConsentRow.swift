//
//  ConsentRow.swift
//  BelloHub
//

import SwiftUI

/// One signed consent: what it was, who signed it and when, and the version of the text. Tapping it opens the exact
/// text that was signed. One element for VoiceOver, with a hint that says what the tap does.
struct ConsentRow: View {
    let consent: Consent
    let formatters: Formatters
    let identifier: String
    let action: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.row) {
                Image(icon: .check)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.sageText)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(
                        Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(ConsentPresentation.title(of: consent.kind))
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(verbatim: ConsentPresentation.signedLine(consent, formatters: formatters, locale: locale))
                        .font(Typography.meta).foregroundStyle(Palette.ink2)
                    Text(verbatim: ConsentPresentation.versionLine(consent.textVersion, locale: locale))
                        .font(Typography.footnote).foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: Spacing.sm)
                Image(icon: .forward)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("health.consent.openHint"))
        .accessibilityIdentifier(identifier)
    }
}
