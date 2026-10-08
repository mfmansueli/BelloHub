//
//  ProfessionCatalog+Bundle.swift
//  BelloHub
//

import Foundation

extension ProfessionCatalog {
    /// Loads the shipped catalog of `localization` (`professions-<localization>.json`). A localization whose file is
    /// missing reads the English one, so a gap never blocks onboarding. Reading the bundle is IO, which is why this is
    /// in `Managers/`.
    static func loadBundled(localization: AppLocalization, in bundle: Bundle = .main) throws -> ProfessionCatalog {
        for candidate in [localization, .en] {
            if let url = bundle.url(forResource: "professions-\(candidate.rawValue)", withExtension: "json") {
                return try decode(Data(contentsOf: url))
            }
        }
        throw LoadError.missingResource
    }
}
