//
//  ServicesStepView.swift
//  BelloHub
//

import SwiftUI

/// 1.4 Onb-3-Services. The services the catalog suggests for her professions, a duration on each, and a way to add
/// one of her own (1.5). Prices are optional and come later.
struct ServicesStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showsCustomService = false
    @Environment(\.locale) private var locale

    var body: some View {
        OnboardingStepLayout(
            title: Text("onb.services.title"), subtitle: subtitle, canContinue: viewModel.canContinue,
            identifier: "services", onContinue: viewModel.goNext
        ) {
            VStack(spacing: Spacing.row) {
                ForEach(viewModel.draft.customServices) { service in
                    ChoiceCard(
                        title: service.name, subtitle: customSubtitle(for: service), emphasizesSubtitle: true,
                        isSelected: true, identifier: "onboarding.services.custom.\(service.id.uuidString)"
                    ) { viewModel.removeCustomService(id: service.id) }
                        .accessibilityHint(Text("onb.services.removeHint"))
                }
                ForEach(viewModel.suggestedServices) { service in
                    ChoiceCard(
                        title: service.name, subtitle: formatters.minutes(service.minutes),
                        isSelected: viewModel.isServiceSelected(service.key),
                        identifier: "onboarding.services.choice.\(service.key)"
                    ) { viewModel.toggleService(service.key) }
                }
                Button { showsCustomService = true } label: { Text("onb.services.addCustom") }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("onboarding.services.addCustomButton")
            }
        }
        .sheet(isPresented: $showsCustomService) {
            CustomServiceSheet(currencyCode: viewModel.draft.currencyCode) { _ = viewModel.addCustomService($0) }
        }
    }

    private var subtitle: Text {
        let names = OnboardingSuggestions.pluralNames(for: viewModel.draft.professions, in: viewModel.catalog,
                                                      formatter: formatters)
        return Text(LocalizedStringResource(
            "onb.services.subtitle",
            defaultValue: "Suggested for \(names). Prices and durations are easy to change later."
        ).localized(in: locale))
    }

    private var formatters: Formatters {
        Formatters(locale: locale, timeZone: .current, currencyCode: viewModel.draft.currencyCode)
    }

    /// "Your service · R$120 · 90 min".
    private func customSubtitle(for service: DraftService) -> String {
        var parts = [LocalizedStringResource(
            "onb.services.yourService", defaultValue: "Your service"
        ).resolved(in: locale)]
        if let price = service.priceAmount { parts.append(formatters.money(price)) }
        parts.append(formatters.minutes(service.minutes))
        return parts.joined(separator: " · ")
    }
}
