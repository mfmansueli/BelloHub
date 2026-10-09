//
//  ConsentPreviewSheet.swift
//  BelloHub
//

import SwiftUI

/// A consent text, read-only, as the client will read it. It is a versioned legal draft: the professional reads it
/// (and can read it in another language) but never edits it. The note above it says it is a draft.
struct ConsentPreviewSheet: View {
    @Bindable var viewModel: ConsentPreviewViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "consentPreview.title", subtitle: ConsentPresentation.title(of: viewModel.document),
                closeLabel: "common.close", closeIdentifier: "consentPreview.closeButton", onClose: { dismiss() }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    LegalLanguagePicker(
                        selection: Binding(
                            get: { viewModel.language }, set: { viewModel.setLanguage($0) }
                        ),
                        identifier: "consentPreview.languagePicker"
                    )
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

    @ViewBuilder
    private var text: some View {
        if let rendered = viewModel.renderedText, let legalText = viewModel.legalText {
            VStack(alignment: .leading, spacing: Spacing.row) {
                Text(verbatim: ConsentPresentation.versionLine(legalText.version, locale: locale))
                    .font(Typography.meta)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("consentPreview.version")
                LegalTextView(text: rendered, language: viewModel.language)
                    .padding(Spacing.md)
                    .belloCard()
                    .accessibilityIdentifier("consentPreview.text")
            }
        } else {
            InlineNotice(style: .warning, title: "legal.error")
                .accessibilityIdentifier("consentPreview.error")
        }
    }
}
