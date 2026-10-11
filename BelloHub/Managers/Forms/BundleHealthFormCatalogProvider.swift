//
//  BundleHealthFormCatalogProvider.swift
//  BelloHub
//

import Foundation

/// Reads `healthform-<localization>.json` from the app bundle. A localization whose file is missing reads the English
/// one, so a gap never leaves a screen without questions. Reading the bundle is IO, which is why this is a Manager.
struct BundleHealthFormCatalogProvider: HealthFormCatalogProviding {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func catalog(for localization: AppLocalization) throws -> HealthFormCatalog {
        for candidate in [localization, .en] {
            if let url = bundle.url(forResource: "healthform-\(candidate.rawValue)", withExtension: "json") {
                return try HealthFormCatalog.decode(Data(contentsOf: url))
            }
        }
        throw HealthFormCatalog.LoadError.missingResource
    }
}
