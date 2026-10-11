//
//  LanguageRegionViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Language and region (7.2): a draft of the business region, language, currency, week start,
/// clock and page languages, the previews that follow every tap, and Save. The rules live in `LanguageRegionRules`
/// and the previews in `LocalePreview`; the ViewModel only holds the draft and talks to the Services.
@MainActor
@Observable
final class LanguageRegionViewModel {
    private(set) var draft: LanguageRegionDraft
    private(set) var isSaving = false
    private(set) var saved = false
    private(set) var errorMessage: String?

    let regions: RegionCatalog
    let professionalName: String
    let timeZone: TimeZone

    private let profile: ProfileService
    private let bookingSetup: BookingSetupService
    private let now: @Sendable () -> Date

    init(
        profile: ProfileService, bookingSetup: BookingSetupService, regions: RegionCatalog,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.profile = profile
        self.bookingSetup = bookingSetup
        self.regions = regions
        self.now = now
        let stored = profile.profile
        draft = stored.map(LanguageRegionDraft.init) ?? LanguageRegionDraft(
            regionCode: "BR", localization: .en, currencyCode: "BRL", bookingLocaleIDs: ["en"]
        )
        professionalName = stored?.firstName ?? ""
        timeZone = stored.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
    }

    // MARK: - Reading

    var presets: [RegionPreset] { regions.presetsForPicker }

    var selectedPreset: RegionPreset? { regions.preset(for: draft.regionCode) }

    var weekConfig: WeekConfig { LanguageRegionRules.effectiveWeekConfig(draft) }

    var currencyOptions: [String] {
        LanguageRegionRules.currencyOptions(current: draft.currencyCode, presets: presets)
    }

    var preview: LocalePreview {
        LocalePreview.make(
            draft: draft, preset: selectedPreset, professionalName: professionalName, timeZone: timeZone, now: now(),
            policy: bookingSetup.hasLoaded
                ? (bookingSetup.setup.cancellation, bookingSetup.setup.noShow) : nil
        )
    }

    var canSave: Bool {
        guard let stored = profile.profile else { return false }
        return !isSaving && LanguageRegionRules.hasChanges(draft, profile: stored)
    }

    func isOnPage(_ localization: AppLocalization) -> Bool {
        draft.bookingLocaleIDs.contains(localization.rawValue)
    }

    // MARK: - Editing

    func choose(_ preset: RegionPreset) {
        draft = LanguageRegionRules.choosing(preset, in: draft)
    }

    func choose(_ localization: AppLocalization) {
        draft = LanguageRegionRules.choosing(localization, in: draft)
    }

    func setCurrency(_ code: String) {
        draft.currencyCode = code
    }

    func setFirstWeekday(_ weekday: Int) {
        draft.firstWeekday = weekday
    }

    func setUse24Hour(_ value: Bool) {
        draft.use24Hour = value
    }

    func setClientTerm(_ term: ClientTerm) {
        draft.clientTerm = term
    }

    func togglePageLanguage(_ localization: AppLocalization) {
        draft = LanguageRegionRules.toggling(localization, in: draft)
    }

    // MARK: - Loading and saving

    func loadPolicies() async {
        try? await bookingSetup.load(timeZoneID: timeZone.identifier)
    }

    func save() {
        Task { await saveAsync() }
    }

    func saveAsync() async {
        guard canSave, let stored = profile.profile else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await profile.saveProfile(draft.applied(to: stored))
            saved = true
        } catch {
            errorMessage = String(interface: LocalizedStringResource(
                "languageRegion.error.save",
                defaultValue: "We could not save your changes. Check that your iPhone has space and try again."
            ))
        }
    }

    func dismissSaved() {
        saved = false
    }
}
