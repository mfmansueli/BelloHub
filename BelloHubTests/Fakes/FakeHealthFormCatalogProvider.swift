//
//  FakeHealthFormCatalogProvider.swift
//  BelloHubTests
//

@testable import BelloHub

/// A catalog provider that always returns the small inline catalog (or fails), so ViewModel tests do not depend on the
/// shipped files.
struct FakeHealthFormCatalogProvider: HealthFormCatalogProviding {
    var inline = makeHealthCatalog()
    var fails = false

    func catalog(for localization: AppLocalization) throws -> HealthFormCatalog {
        if fails { throw HealthFormCatalog.LoadError.missingResource }
        return inline
    }
}
