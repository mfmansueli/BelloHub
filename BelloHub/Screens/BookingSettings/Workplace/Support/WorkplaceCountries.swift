//
//  WorkplaceCountries.swift
//  BelloHub
//

import Foundation

/// The countries the "Where you work" menu offers: her business region first (it is almost always the answer), then
/// every other country by its name in the screen's language. Pure, so the order is tested.
enum WorkplaceCountries {
    /// Two-letter codes that are groupings or placeholders, not places a studio can be in.
    private static let notCountries: Set<String> = ["EU", "EZ", "UN", "QO", "ZZ", "XA", "XB"]

    static func codes(businessRegion: String, locale: Locale) -> [String] {
        let region = businessRegion.uppercased()
        let all = Locale.Region.isoRegions
            .map(\.identifier)
            .filter { $0.count == 2 && $0.allSatisfy(\.isLetter) && $0 != region && !notCountries.contains($0) }
            .filter { locale.localizedString(forRegionCode: $0) != nil }
        let sorted = all.sorted {
            name($0, locale: locale).localizedStandardCompare(name($1, locale: locale)) == .orderedAscending
        }
        return region.isEmpty ? sorted : [region] + sorted
    }

    static func name(_ code: String, locale: Locale) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }
}
