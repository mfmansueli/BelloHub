//
//  ServicesStepView.swift
//  BelloHub
//

import SwiftUI

/// 1.4 Onb-3, "Your first service" (routine-a item 3). One service is enough to start: the most common one of her
/// first profession is chosen, with its usual duration and an optional price in her region's currency. Other
/// suggestions are offered as optional extras, and her own service is one sheet away (1.5). Everything else about
/// services waits in More, Services.
struct ServicesStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showsCustomService = false
    @State private var priceText = ""
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        OnboardingStepLayout(
            title: Text("onb.firstService.title"), subtitle: Text("onb.firstService.subtitle"),
            canContinue: canContinue, identifier: "services", onContinue: viewModel.goNext
        ) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let first = viewModel.firstService { firstServiceCard(first) }
                customServices
                if !viewModel.otherServices.isEmpty { extras }
                Button { showsCustomService = true } label: { Text("onb.services.addCustom") }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("onboarding.services.addCustomButton")
            }
        }
        .sheet(isPresented: $showsCustomService) {
            CustomServiceSheet(currencyCode: viewModel.draft.currencyCode) { _ = viewModel.addCustomService($0) }
        }
        .onAppear(perform: showStoredPrice)
        .onChange(of: viewModel.draft.firstServiceKey) { showStoredPrice() }
    }

    // MARK: - First service

    private func firstServiceCard(_ service: SuggestedService) -> some View {
        ListCard(dividerInset: Spacing.md) {
            row("onb.firstService.service") {
                Picker(selection: firstServiceBinding) {
                    ForEach(viewModel.suggestedServices) { item in
                        Text(verbatim: item.name).tag(item.key)
                    }
                } label: { Text("onb.firstService.service") }
                    .pickerStyle(.menu)
                    .tint(Palette.ink)
                    .accessibilityIdentifier("onboarding.services.firstMenu")
            }
            row("onb.service.duration") {
                Picker(selection: minutesBinding(service)) {
                    ForEach(durationOptions(for: service), id: \.self) { minutes in
                        Text(verbatim: formatters.minutes(minutes)).tag(minutes)
                    }
                } label: { Text("onb.service.duration") }
                    .pickerStyle(.menu)
                    .tint(Palette.ink)
                    .accessibilityIdentifier("onboarding.services.durationMenu")
            }
            row("onb.firstService.price") {
                TextField(text: $priceText, prompt: Text(verbatim: formatters.money(0)).foregroundStyle(Palette.ink2)) {
                    Text("onb.firstService.price")
                }
                .keyboardType(.decimalPad)
                .foregroundStyle(parsedPrice.isInvalid ? Palette.coralText : Palette.ink)
                .onChange(of: priceText) { viewModel.setPrice(parsedPrice.amount, of: service) }
                .accessibilityIdentifier("onboarding.services.priceField")
            }
        }
        .accessibilityIdentifier("onboarding.services.firstCard")
    }

    /// Label beside the value; above it at the accessibility sizes, where a side label would squeeze the value.
    private func row<Field: View>(_ label: LocalizedStringKey, @ViewBuilder field: () -> Field) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Spacing.md))
        return layout {
            Text(label).font(Typography.body).foregroundStyle(Palette.ink2)
                .frame(minWidth: typeSize.isAccessibilitySize ? nil : 96, alignment: .leading)
            field().font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 56)
    }

    // MARK: - Her own and the extras

    @ViewBuilder
    private var customServices: some View {
        ForEach(viewModel.draft.customServices) { service in
            ChoiceCard(
                title: service.name, subtitle: customSubtitle(for: service), emphasizesSubtitle: true,
                isSelected: true, identifier: "onboarding.services.custom.\(service.id.uuidString)"
            ) { viewModel.removeCustomService(id: service.id) }
                .accessibilityHint(Text("onb.services.removeHint"))
        }
    }

    private var extras: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            Text("onb.firstService.more").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            ForEach(viewModel.otherServices) { service in
                ChoiceCard(
                    title: service.name, subtitle: formatters.minutes(service.minutes),
                    isSelected: viewModel.isServiceSelected(service.key),
                    identifier: "onboarding.services.choice.\(service.key)"
                ) { viewModel.toggleService(service.key) }
            }
        }
    }

    // MARK: - Helpers

    /// A first service is needed to continue, unless she added one of her own.
    private var canContinue: Bool {
        (viewModel.firstService != nil || !viewModel.draft.customServices.isEmpty) && !parsedPrice.isInvalid
    }

    private var parsedPrice: PriceInput { PriceInput(priceText, locale: locale) }

    private var formatters: Formatters {
        Formatters(locale: locale, timeZone: .current, currencyCode: viewModel.draft.currencyCode)
    }

    private var firstServiceBinding: Binding<String> {
        Binding(get: { viewModel.draft.firstServiceKey ?? "" }, set: viewModel.chooseFirstService)
    }

    private func minutesBinding(_ service: SuggestedService) -> Binding<Int> {
        Binding(get: { viewModel.minutes(of: service) }, set: { viewModel.setMinutes($0, of: service) })
    }

    /// The menu's durations, with the catalog's own value even when it is not one of the usual steps.
    private func durationOptions(for service: SuggestedService) -> [Int] {
        Array(Set(OnboardingRules.durationOptions + [service.minutes, viewModel.minutes(of: service)])).sorted()
    }

    /// The price field shows what is stored for the chosen service (after a relaunch, or after switching back).
    private func showStoredPrice() {
        guard let service = viewModel.firstService else { return }
        priceText = viewModel.price(of: service).map { $0.formatted(.number.locale(locale).grouping(.never)) } ?? ""
    }

    /// "Your service · R$120 · 90 min".
    private func customSubtitle(for service: DraftService) -> String {
        var parts = [LocalizedStringResource("onb.services.yourService", defaultValue: "Your service").resolved(in: locale)]
        if let price = service.priceAmount { parts.append(formatters.money(price)) }
        parts.append(formatters.minutes(service.minutes))
        return parts.joined(separator: " · ")
    }
}
