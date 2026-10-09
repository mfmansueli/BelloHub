//
//  ProfessionalProfile.swift
//  BelloHub
//

import Foundation

/// The one profile of the signed-in professional (docs/05-DATA-MODEL.md section 2). It lives in the vault, in the
/// clear: nothing in it is clinical. The public page gets a copy of the fields the client needs, never the whole value.
///
/// Fields owned by the server (plan, bans) are not here: the app only reads them (CLAUDE.md section 2, Backend).
struct ProfessionalProfile: Identifiable, Hashable, Codable, Sendable {
    /// There is exactly one profile per vault, so its id is fixed. That makes "save the profile" an upsert and keeps
    /// a second device from creating a second one while the first syncs.
    static let singletonID = UUID(uuidString: "B3110000-0000-4000-8000-000000000001") ?? UUID()

    let id: UUID
    var displayName: String
    /// Optional: shown on the booking page and messages instead of her own name when set.
    var businessName: String
    /// ISO 3166-1 alpha-2 of the business region (`RegionPreset.code`).
    var regionCode: String
    var timeZoneID: String
    var currencyCode: String
    /// One of the fourteen localizations (`AppLocalization.rawValue`): messages, templates and the booking page.
    var appLocaleID: String
    /// Languages the public page offers; the business localization is always on.
    var bookingLocaleIDs: [String]
    /// Her week start (1 = Sunday ... 7 = Saturday) when she overrode the region's default; nil follows the region.
    var firstWeekday: Int?
    /// Her clock when she overrode the region's default; nil follows the region (docs/07-LOCALIZATION.md section 3).
    var use24Hour: Bool?
    var professions: [ProfessionID]
    var clientTerm: ClientTerm
    var vocabulary: [VocabularyTerm]
    var createdAt: Date
    var updatedAt: Date

    init(
        displayName: String,
        businessName: String = "",
        regionCode: String,
        timeZoneID: String,
        currencyCode: String,
        appLocaleID: String,
        bookingLocaleIDs: [String] = [],
        firstWeekday: Int? = nil,
        use24Hour: Bool? = nil,
        professions: [ProfessionID] = [],
        clientTerm: ClientTerm = .client,
        vocabulary: [VocabularyTerm] = [],
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = Self.singletonID
        self.displayName = displayName
        self.businessName = businessName
        self.regionCode = regionCode
        self.timeZoneID = timeZoneID
        self.currencyCode = currencyCode
        self.appLocaleID = appLocaleID
        self.bookingLocaleIDs = bookingLocaleIDs
        self.firstWeekday = firstWeekday
        self.use24Hour = use24Hour
        self.professions = professions
        self.clientTerm = clientTerm
        self.vocabulary = vocabulary
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    /// What the app calls her in greetings: the first word of her name ("Maria").
    var firstName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }

    /// The name that identifies the business: its own name when she set one, otherwise hers.
    var publicName: String {
        businessName.isEmpty ? displayName : businessName
    }
}
