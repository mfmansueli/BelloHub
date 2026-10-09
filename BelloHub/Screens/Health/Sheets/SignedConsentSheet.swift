//
//  SignedConsentSheet.swift
//  BelloHub
//

import SwiftUI

/// The exact text a consent was signed on, with who signed it, when, the version and the language. If this iPhone does
/// not have that version (it was signed on a newer build of the app) it says so instead of showing another text.
struct SignedConsentSheet: View {
    let viewModel: SignedConsentViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: ConsentPresentation.title(of: viewModel.consent.kind), closeLabel: "common.close",
                closeIdentifier: "signedConsent.closeButton", onClose: { dismiss() }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    details
                    text
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .background(Palette.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Parts

    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(verbatim: ConsentPresentation.signedLine(
                viewModel.consent, formatters: viewModel.formatters, locale: locale
            ))
            .font(Typography.bodyStrong)
            .foregroundStyle(Palette.ink)
            .accessibilityIdentifier("signedConsent.signedBy")
            Text(verbatim: ConsentPresentation.versionLine(viewModel.consent.textVersion, locale: locale))
                .font(Typography.meta)
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("signedConsent.version")
            if let language = viewModel.localization {
                Text(LocalizedStringResource(
                    "signedConsent.written", defaultValue: "Written in \(BidiIsolate.wrap(language.nativeName))"
                ).localized(in: locale))
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("signedConsent.language")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var text: some View {
        if let rendered = viewModel.renderedText {
            LegalTextView(text: rendered, language: viewModel.localization)
                .padding(Spacing.md)
                .belloCard()
                .accessibilityIdentifier("signedConsent.text")
        } else {
            InlineNotice(
                style: .warning, title: "signedConsent.missing.title", message: "signedConsent.missing.message"
            )
            .accessibilityIdentifier("signedConsent.missing")
        }
    }
}
