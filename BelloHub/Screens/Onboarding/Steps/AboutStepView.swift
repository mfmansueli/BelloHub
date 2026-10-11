//
//  AboutStepView.swift
//  BelloHub
//

import SwiftUI

/// Onb-1b About you (added in S3): her name, and optionally the name of the business. The name greets her in the
/// app and appears on the booking page; nothing else is asked here.
struct AboutStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        OnboardingStepLayout(
            title: Text("onb.about.title"), subtitle: Text("onb.about.subtitle"), canContinue: viewModel.canContinue,
            identifier: "about", onContinue: viewModel.goNext
        ) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                BelloTextField(
                    title: "onb.about.name", text: nameBinding, prompt: "onb.about.namePrompt",
                    errorMessage: showsNameError ? "onb.about.nameError" : nil, identifier: "onboarding.about.nameField"
                )
                .textContentType(.name)
                BelloTextField(
                    title: "onb.about.business", text: businessBinding, prompt: "onb.about.businessPrompt",
                    identifier: "onboarding.about.businessField"
                )
                regionPicker
            }
        }
    }

    /// Where she works: sets the currency, the time zone and the booking page languages. Starts from the phone's
    /// region. The native menu picker, so the label and the chosen value lay themselves out at every text size.
    private var regionPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Picker(selection: regionBinding) {
                ForEach(viewModel.regions.presetsForPicker) { preset in
                    Text(verbatim: label(of: preset)).tag(preset)
                }
            } label: {
                Text("onb.about.region").font(Typography.body).foregroundStyle(Palette.ink)
            }
            .pickerStyle(.menu)
            .tint(Palette.ink)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 52)
            .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                    .strokeBorder(Palette.fieldBorder, lineWidth: 1.5)
            }
            .accessibilityIdentifier("onboarding.about.regionMenu")
            Text("onb.about.regionHint").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    private var regionBinding: Binding<RegionPreset> {
        Binding(
            get: { viewModel.region ?? viewModel.regions.presetsForPicker[0] },
            set: viewModel.setRegion
        )
    }

    /// "🇧🇷 Brazil · BRL".
    private func label(of preset: RegionPreset) -> String {
        let name = locale.localizedString(forRegionCode: preset.code) ?? preset.code
        return "\(SignInRegionMenu.flag(preset.code))  \(name) · \(preset.defaultCurrency)"
    }

    private var nameBinding: Binding<String> {
        Binding(get: { viewModel.draft.displayName }, set: viewModel.setDisplayName)
    }

    private var businessBinding: Binding<String> {
        Binding(get: { viewModel.draft.businessName }, set: viewModel.setBusinessName)
    }

    /// Only after she typed something that is not enough yet, so an empty field is not scolded.
    private var showsNameError: Bool {
        let name = OnboardingRules.cleaned(viewModel.draft.displayName)
        return !name.isEmpty && !OnboardingRules.isValidPersonName(name)
    }
}
