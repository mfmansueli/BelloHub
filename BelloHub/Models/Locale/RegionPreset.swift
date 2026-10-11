//
//  RegionPreset.swift
//  BelloHub
//

import Foundation

/// A region's defaults (docs/16-MARKETS.md section 1). Pure data: `regions.json` is the single table.
/// The professional's business region selects a preset; she can override currency, week start and clock.
struct RegionPreset: Codable, Hashable, Identifiable, Sendable {
    /// ISO 3166-1 alpha-2.
    let code: String
    let defaultCurrency: String
    /// Digits only, without the plus (Brazil is "55").
    let callingCode: String
    /// Leading digit a national number may start with and that is dropped in E.164 ("0" in most of
    /// Europe and Asia). Nil where the number is used as it is, as in Italy, Spain and the United States.
    let trunkPrefix: String?
    /// Display patterns by number of national digits; `#` is a digit. Falls back to groups of three.
    let phonePatterns: [String: String]
    /// Plausible national lengths (without the trunk prefix), used to reject typos.
    let nationalLengths: [Int]
    let defaultLocalization: String
    /// Languages the booking page offers by default; the first is the default.
    let localizations: [String]
    let messagingChannel: MessagingChannel
    let privacyFrameworkId: String
    let healthDataResidency: HealthDataResidency
    /// 1 to 4: when the market opens (D36).
    let wave: Int
    /// IANA identifiers offered first.
    let timeZones: [String]

    var id: String { code }
}
