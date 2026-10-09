//
//  CatalogNameRules.swift
//  BelloHub
//

import Foundation

/// The one rule for the names of what she offers (services, add-ons, products): cleaned of stray spaces, not empty, not
/// too long and not the name of another one of the same kind, ignoring case and accents. It builds on the same
/// comparison the tags and the record fields use, so every "is this name taken?" answer in the app agrees.
enum CatalogNameRules {
    static let maximumLength = 60

    /// `others` are the names of the rest of the list (the one being edited left out).
    static func check(_ raw: String, among others: [String], maximumLength: Int = maximumLength) -> CatalogNameCheck {
        let name = OnboardingRules.cleaned(raw)
        guard !name.isEmpty else { return .empty }
        guard name.count <= maximumLength else { return .tooLong }
        guard OnboardingRules.acceptedName(name, existing: others) != nil else { return .duplicate }
        return .accepted(name)
    }
}
