//
//  LanguageRegionContentView.swift
//  BelloHub
//

import SwiftUI

/// The business region (the presets of docs/16-MARKETS.md), the business language, what that sets, the currency,
/// the week start and clock, the message previews, the words the app uses and the booking page languages. Nothing is
/// stored until Save.
struct LanguageRegionContentView: View {
    @State private var viewModel: LanguageRegionViewModel

    @Environment(\.locale) private var locale
    @Environment(ProfileService.self) private var profile

    init(profile: ProfileService, bookingSetup: BookingSetupService, regions: RegionCatalog) {
        _viewModel = State(initialValue: LanguageRegionViewModel(
            profile: profile, bookingSetup: bookingSetup, regions: regions
        ))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("languageRegion.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                notices
                regionSection
                languageSection
                setsSection
                currencySection
                weekSection
                messagesSection
                wordsSection
                pageLanguagesSection
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("languageRegion.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: viewModel.save) { Text("languageRegion.save") }
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("languageRegion.saveButton")
            }
        }
        .task { await viewModel.loadPolicies() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var notices: some View {
        if let message = viewModel.errorMessage {
            ErrorNotice(message: message).accessibilityIdentifier("languageRegion.error")
        }
        if viewModel.saved {
            InlineNotice(style: .info, title: "languageRegion.saved")
                .accessibilityIdentifier("languageRegion.savedNotice")
                .task {
                    try? await Task.sleep(for: .seconds(3))
                    viewModel.dismissSaved()
                }
        }
    }

    /// The region presets as selectable rows, the chosen one ticked.
    private var regionSection: some View {
        SettingsSection(title: "languageRegion.section.region") {
            ListCard(dividerInset: 72) {
                ForEach(viewModel.presets) { preset in
                    regionRow(preset)
                }
            }
        }
    }

    private func regionRow(_ preset: RegionPreset) -> some View {
        let isSelected = preset.code == viewModel.draft.regionCode
        return Button { viewModel.choose(preset) } label: {
            HStack(spacing: Spacing.row) {
                Text(verbatim: preset.code)
                    .font(Typography.metaStrong)
                    .foregroundStyle(isSelected ? Palette.inkOnFill : Palette.ink)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(
                        isSelected ? Palette.ink : Palette.sunken,
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: locale.localizedString(forRegionCode: preset.code) ?? preset.code)
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(verbatim: regionSubtitle(preset)).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(icon: .check).foregroundStyle(Palette.sageText).accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("languageRegion.region.\(preset.code)")
    }

    private func regionSubtitle(_ preset: RegionPreset) -> String {
        let language = AppLocalization(rawValue: preset.defaultLocalization)?.nativeName ?? preset.defaultLocalization
        return "\(language) · \(preset.defaultCurrency)"
    }

    /// The language of her messages and page, apart from the region (a Spanish speaker in the United States).
    private var languageSection: some View {
        SettingsSection(title: "languageRegion.section.language", subtitle: "languageRegion.section.language.subtitle") {
            ListCard(dividerInset: Spacing.md) {
                HStack(spacing: Spacing.row) {
                    Text("languageRegion.language").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker(selection: languageBinding) {
                        ForEach(AppLocalization.allCases) { localization in
                            Text(verbatim: localization.nativeName).tag(localization)
                        }
                    } label: {
                        Text("languageRegion.language")
                    }
                    .pickerStyle(.menu)
                    .tint(Palette.roseText)
                    .accessibilityIdentifier("languageRegion.languageMenu")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
        }
    }

    private var setsSection: some View {
        SettingsSection(title: "languageRegion.section.sets") {
            ListCard(dividerInset: Spacing.md) {
                ForEach(viewModel.preview.rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.row) {
                        Text(LocalizedStringKey(row.key)).font(Typography.meta).foregroundStyle(Palette.ink2)
                        Spacer(minLength: Spacing.sm)
                        Text(verbatim: row.value).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(row.key)
                }
            }
        }
    }

    private var currencySection: some View {
        SettingsSection(title: "languageRegion.section.currency", subtitle: "languageRegion.section.currency.subtitle") {
            ListCard(dividerInset: Spacing.md) {
                HStack(spacing: Spacing.row) {
                    Text("languageRegion.currency").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker(selection: currencyBinding) {
                        ForEach(viewModel.currencyOptions, id: \.self) { code in
                            Text(verbatim: currencyLabel(code)).tag(code)
                        }
                    } label: {
                        Text("languageRegion.currency")
                    }
                    .pickerStyle(.menu)
                    .tint(Palette.roseText)
                    .accessibilityIdentifier("languageRegion.currencyMenu")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
        }
    }

    private var weekSection: some View {
        SettingsSection(title: "languageRegion.section.week") {
            ListCard(dividerInset: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("languageRegion.weekStart").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Picker(selection: weekStartBinding) {
                        ForEach(LanguageRegionRules.weekStartOptions, id: \.self) { weekday in
                            Text(verbatim: LocalePreview.weekdayName(weekday, locale: locale)).tag(weekday)
                        }
                    } label: {
                        Text("languageRegion.weekStart")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("languageRegion.weekStartPicker")
                }
                .padding(Spacing.md)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("languageRegion.clock").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Picker(selection: clockBinding) {
                        Text("languageRegion.clock.24").tag(true)
                        Text("languageRegion.clock.12").tag(false)
                    } label: {
                        Text("languageRegion.clock")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("languageRegion.clockPicker")
                }
                .padding(Spacing.md)
            }
        }
    }

    /// Two quick replies and the cancellation rules, as a client in that language reads them.
    private var messagesSection: some View {
        SettingsSection(title: "languageRegion.section.messages", subtitle: "languageRegion.section.messages.subtitle") {
            VStack(alignment: .leading, spacing: Spacing.row) {
                ForEach(Array(viewModel.preview.messages.enumerated()), id: \.offset) { index, message in
                    previewBubble(message, identifier: "languageRegion.message.\(index)")
                }
                if !viewModel.preview.policyLines.isEmpty {
                    previewBubble(
                        viewModel.preview.policyLines.joined(separator: " "), identifier: "languageRegion.policyPreview"
                    )
                }
            }
        }
    }

    private func previewBubble(_ text: String, identifier: String) -> some View {
        Text(verbatim: text)
            .font(Typography.body)
            .foregroundStyle(Palette.ink)
            .environment(\.layoutDirection, viewModel.draft.localization.isRightToLeft ? .rightToLeft : .leftToRight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .accessibilityIdentifier(identifier)
    }

    private var wordsSection: some View {
        SettingsSection(title: "languageRegion.section.words", subtitle: "languageRegion.section.words.subtitle") {
            ListCard(dividerInset: Spacing.md) {
                HStack(spacing: Spacing.row) {
                    Text("languageRegion.clientTerm").font(Typography.meta).foregroundStyle(Palette.ink2)
                    Spacer(minLength: Spacing.sm)
                    Text(verbatim: profile.clientTerm.titlePlural(in: viewModel.draft.localization.locale))
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("languageRegion.clientTermRow")
            }
        }
    }

    /// Every localization as a switch; the business language is on and cannot be switched off.
    private var pageLanguagesSection: some View {
        SettingsSection(title: "languageRegion.section.pageLanguages", subtitle: "languageRegion.section.pageLanguages.subtitle") {
            ListCard(dividerInset: Spacing.md) {
                ForEach(AppLocalization.allCases) { localization in
                    ToggleRow(
                        title: localization.nativeName,
                        subtitle: localization == viewModel.draft.localization
                            ? String(localized: "languageRegion.pageLanguage.business") : nil,
                        isOn: Binding(
                            get: { viewModel.isOnPage(localization) },
                            set: { _ in viewModel.togglePageLanguage(localization) }
                        ),
                        identifier: "languageRegion.pageLanguage.\(localization.rawValue)"
                    )
                    .disabled(localization == viewModel.draft.localization)
                }
            }
        }
    }

    // MARK: - Bindings

    private var languageBinding: Binding<AppLocalization> {
        Binding(get: { viewModel.draft.localization }, set: { viewModel.choose($0) })
    }

    private var currencyBinding: Binding<String> {
        Binding(get: { viewModel.draft.currencyCode }, set: { viewModel.setCurrency($0) })
    }

    private var weekStartBinding: Binding<Int> {
        Binding(get: { viewModel.weekConfig.firstWeekday }, set: { viewModel.setFirstWeekday($0) })
    }

    private var clockBinding: Binding<Bool> {
        Binding(get: { viewModel.weekConfig.use24Hour }, set: { viewModel.setUse24Hour($0) })
    }

    private func currencyLabel(_ code: String) -> String {
        let name = locale.localizedString(forCurrencyCode: code) ?? code
        return "\(code) · \(name)"
    }
}
