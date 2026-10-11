//
//  OnboardingDraft.swift
//  BelloHub
//

import Foundation

/// Everything she has chosen so far in the setup, as plain values. Nothing is saved until the end: the draft
/// becomes a profile, services, tags and a record template in one step (`OnboardingBuilder`).
struct OnboardingDraft: Equatable, Codable, Sendable {
    var displayName = ""
    var businessName = ""
    var regionCode: String
    var timeZoneID: String
    var currencyCode: String
    var localization: AppLocalization
    var bookingLocaleIDs: [String]

    /// In the order she chose them; the first one names the workspace.
    var professions: [ProfessionID] = []
    var selectedServiceKeys: Set<String> = []
    /// The service she starts with (a suggestion's key, always selected); nil only when her professions suggest none.
    var firstServiceKey: String?
    /// Durations she set for suggested services, by key (the catalog's duration otherwise).
    var serviceMinutes: [String: Int] = [:]
    /// Prices she typed for suggested services, by key (none otherwise: prices are optional).
    var servicePrices: [String: Decimal] = [:]
    var customServices: [DraftService] = []
    var clientTerm: ClientTerm = .client
    var vocabulary: [VocabularyTerm] = []
    var selectedTagKeys: Set<String> = []
    var customTags: [String] = []
    /// Record fields she changed from the catalog's default, keyed by `RecordFieldSetting.id`.
    var fieldOverrides: [String: Bool] = [:]
    /// Intake items she changed from the catalog's default, keyed by `IntakeSetting.id`.
    var intakeOverrides: [String: Bool] = [:]
    /// Profession whose record fields the Record step shows.
    var recordProfession: ProfessionID?

    init(preset: RegionPreset, timeZoneID: String, localization: AppLocalization) {
        self.regionCode = preset.code
        self.timeZoneID = timeZoneID
        self.currencyCode = preset.defaultCurrency
        self.localization = localization
        self.bookingLocaleIDs = preset.localizations
    }

    /// Moves the business to another region: its currency, its time zone (the phone's when the region uses it) and the
    /// languages its booking page offers. The business language stays as it is; changing it is `LanguageRegion` (7.2).
    mutating func changeRegion(to preset: RegionPreset, deviceTimeZoneID: String) {
        regionCode = preset.code
        currencyCode = preset.defaultCurrency
        timeZoneID = preset.timeZones.contains(deviceTimeZoneID)
            ? deviceTimeZoneID : (preset.timeZones.first ?? deviceTimeZoneID)
        bookingLocaleIDs = preset.localizations
    }

    /// The starting point from what the phone says about its owner: the business region is the device region (or the
    /// closest preset), the language is the closest of the fourteen, and the time zone is the phone's when the region
    /// uses it. She can change region and language later (7.2).
    static func initial(
        regions: RegionCatalog, deviceRegion: String?, languageCode: String?, preferredLanguages: [String],
        deviceTimeZoneID: String
    ) -> OnboardingDraft {
        let preset = regions.preset(deviceRegion: deviceRegion, languageCode: languageCode)
        let localization = AppLocalization.resolve(preferredLanguages: preferredLanguages, regionCode: deviceRegion)
            ?? AppLocalization(rawValue: preset.defaultLocalization) ?? .en
        let timeZoneID = preset.timeZones.contains(deviceTimeZoneID)
            ? deviceTimeZoneID : (preset.timeZones.first ?? deviceTimeZoneID)
        return OnboardingDraft(preset: preset, timeZoneID: timeZoneID, localization: localization)
    }
}
