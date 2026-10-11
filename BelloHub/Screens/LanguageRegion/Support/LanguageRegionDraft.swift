//
//  LanguageRegionDraft.swift
//  BelloHub
//

import Foundation

/// What Language and region (7.2) edits before Save: the business region, the business language, the currency, the
/// week start and clock overrides, and the languages the booking page offers. Pure value; the rules that keep it
/// consistent are in `LanguageRegionRules`.
struct LanguageRegionDraft: Equatable, Sendable {
    var regionCode: String
    var localization: AppLocalization
    var currencyCode: String
    /// Nil follows the region's default.
    var firstWeekday: Int?
    var use24Hour: Bool?
    var bookingLocaleIDs: [String]
    /// What she calls the people she serves (chosen here since the setup no longer asks, routine-a item 3).
    var clientTerm: ClientTerm = .client

    init(profile: ProfessionalProfile) {
        regionCode = profile.regionCode
        localization = AppLocalization(rawValue: profile.appLocaleID) ?? .en
        currencyCode = profile.currencyCode
        firstWeekday = profile.firstWeekday
        use24Hour = profile.use24Hour
        bookingLocaleIDs = profile.bookingLocaleIDs
        clientTerm = profile.clientTerm
    }

    init(
        regionCode: String, localization: AppLocalization, currencyCode: String, firstWeekday: Int? = nil,
        use24Hour: Bool? = nil, bookingLocaleIDs: [String]
    ) {
        self.regionCode = regionCode
        self.localization = localization
        self.currencyCode = currencyCode
        self.firstWeekday = firstWeekday
        self.use24Hour = use24Hour
        self.bookingLocaleIDs = bookingLocaleIDs
    }

    /// The profile with this draft written in; nothing else of the profile changes.
    func applied(to profile: ProfessionalProfile) -> ProfessionalProfile {
        var updated = profile
        updated.regionCode = regionCode
        updated.appLocaleID = localization.rawValue
        updated.currencyCode = currencyCode
        updated.firstWeekday = firstWeekday
        updated.use24Hour = use24Hour
        updated.bookingLocaleIDs = bookingLocaleIDs
        updated.clientTerm = clientTerm
        return updated
    }
}
