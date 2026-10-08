//
//  HealthFormCatalogProviding.swift
//  BelloHub
//

/// Where the health form catalog of a language comes from. The app reads the bundle; tests pass an inline catalog.
protocol HealthFormCatalogProviding: Sendable {
    /// The catalog of `localization`, or the English one when that language has no file.
    func catalog(for localization: AppLocalization) throws -> HealthFormCatalog
}
