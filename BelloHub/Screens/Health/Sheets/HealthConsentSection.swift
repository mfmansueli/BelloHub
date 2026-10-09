//
//  HealthConsentSection.swift
//  BelloHub
//

import SwiftUI

/// The consent part of the health form sheet: the text the person reads (the guardian's for a minor), the language it
/// is shown in, the box she ticks and the name she types. What is read here is exactly what the saved consent refers
/// to by version and language.
struct HealthConsentSection: View {
    @Bindable var viewModel: HealthFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            Text("health.section.consent")
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            LegalLanguagePicker(
                selection: Binding(
                    get: { viewModel.textLanguage }, set: { viewModel.setTextLanguage($0) }
                ),
                identifier: "healthForm.languagePicker"
            )
            consentText
            agreeToggle
            BelloTextField(
                title: viewModel.draft.isForMinor ? "healthForm.signature.guardian" : "healthForm.signature",
                text: $viewModel.draft.signature, prompt: "healthForm.fullName.prompt", isSensitive: true,
                identifier: "healthForm.signatureField"
            )
        }
    }

    @ViewBuilder
    private var consentText: some View {
        if let rendered = viewModel.renderedText {
            LegalTextView(text: rendered, language: viewModel.textLanguage)
                .padding(Spacing.md)
                .belloCard()
                .accessibilityIdentifier("healthForm.consentText")
        } else {
            InlineNotice(style: .warning, title: "legal.error")
                .accessibilityIdentifier("healthForm.consentError")
        }
    }

    /// A parent or guardian agrees as such; everyone else agrees for themselves.
    private var agreeKey: LocalizedStringKey {
        viewModel.draft.isForMinor ? "healthForm.agree.guardian" : "healthForm.agree"
    }

    private var agreeToggle: some View {
        Toggle(isOn: $viewModel.draft.agrees) {
            Text(agreeKey)
                .font(Typography.bodyStrong)
                .foregroundStyle(Palette.ink)
        }
        .tint(Palette.sage)
        .disabled(viewModel.renderedText == nil)
        .padding(Spacing.md)
        .frame(minHeight: 52)
        // A switch outside a list only toggles on the switch itself, but the sentence beside it is what a person
        // taps to agree: the whole card toggles. VoiceOver still finds one switch with its label.
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.renderedText != nil { viewModel.draft.agrees.toggle() }
        }
        .belloCard()
        .accessibilityIdentifier("healthForm.agreeToggle")
    }
}
