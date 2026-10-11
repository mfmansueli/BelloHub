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
    @Environment(InterfaceLanguageService.self) private var interfaceLanguage

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
                appLanguageSection
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

    /// The language of the app itself (routine-a item 1). Applied at once, without Save: it is a setting of this
    /// iPhone, not of the business, and every open screen follows it.
    private var appLanguageSection: some View {
        SettingsSection(
            title: "languageRegion.section.appLanguage", subtitle: "languageRegion.section.appLanguage.subtitle"
        ) {
            ListCard(dividerInset: Spacing.md) {
                HStack(spacing: Spacing.row) {
                    Text("languageRegion.language").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker(selection: appLanguageBinding) {
                        Text("languageRegion.appLanguage.system").tag(InterfaceLanguage.system)
                        ForEach(AppLocalization.allCases) { localization in
                            Text(verbatim: localization.nativeName).tag(InterfaceLanguage.fixed(localization))
                        }
                    } label: {
                        Text("languageRegion.language")
                    }
                    .pickerStyle(.menu)
                    .tint(Palette.roseText)
                    .accessibilityIdentifier("languageRegion.appLanguageMenu")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            FooterNote(text: "languageRegion.appLanguage.system.note", icon: .info)
                .padding(.top, Spacing.xs)
        }
    }

    /// The region presets as selectable rows, the chosen one ticked.
    private var regionSection: some View {
        SettingsSection(title: "languageRegion.section.region") {
            ListCard(dividerInset: 72) {
                ForEach(viewModel.presets) { preset in
                    RegionPresetRow(preset: preset, isSelected: preset.code == viewModel.draft.regionCode) {
                        viewModel.choose(preset)
                    }
                }
            }
        }
    }

    /// The language of her messages and page, apart from the region (a Spanish speaker in the United States).
    private var languageSection: some View {
        SettingsSection(
            title: "languageRegion.section.language", subtitle: "languageRegion.section.language.subtitle"
        ) {
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
        SettingsSection(
            title: "languageRegion.section.currency", subtitle: "languageRegion.section.currency.subtitle"
        ) {
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
            WeekClockCard(firstWeekday: weekStartBinding, use24Hour: clockBinding)
        }
    }

    /// Two quick replies and the cancellation rules, as a client in that language reads them.
    private var messagesSection: some View {
        SettingsSection(
            title: "languageRegion.section.messages", subtitle: "languageRegion.section.messages.subtitle"
        ) {
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
                // Editable here since the setup no longer asks (routine-a item 3); saved with the rest on Save.
                HStack(spacing: Spacing.row) {
                    Text("languageRegion.clientTerm").font(Typography.meta).foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker(selection: clientTermBinding) {
                        ForEach(ClientTerm.allCases) { term in
                            Text(verbatim: term.titlePlural(in: locale)).tag(term)
                        }
                    } label: {
                        Text("languageRegion.clientTerm")
                    }
                    .pickerStyle(.menu)
                    .tint(Palette.roseText)
                    .accessibilityIdentifier("languageRegion.clientTermMenu")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .accessibilityIdentifier("languageRegion.clientTermRow")
            }
        }
    }

    /// Every localization as a switch; the business language is on and cannot be switched off.
    private var pageLanguagesSection: some View {
        SettingsSection(
            title: "languageRegion.section.pageLanguages", subtitle: "languageRegion.section.pageLanguages.subtitle"
        ) {
            ListCard(dividerInset: Spacing.md) {
                ForEach(AppLocalization.allCases) { localization in
                    ToggleRow(
                        title: localization.nativeName,
                        subtitle: localization == viewModel.draft.localization
                            ? String(interface: LocalizedStringResource("languageRegion.pageLanguage.business")) : nil,
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

    private var appLanguageBinding: Binding<InterfaceLanguage> {
        Binding(get: { interfaceLanguage.choice }, set: { interfaceLanguage.choose($0) })
    }

    private var languageBinding: Binding<AppLocalization> {
        Binding(get: { viewModel.draft.localization }, set: { viewModel.choose($0) })
    }

    private var clientTermBinding: Binding<ClientTerm> {
        Binding(get: { viewModel.draft.clientTerm }, set: { viewModel.setClientTerm($0) })
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
