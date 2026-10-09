//
//  CatalogNameCheck.swift
//  BelloHub
//

/// What `CatalogNameRules.check` says about a name she typed for a service, an add-on or a product.
enum CatalogNameCheck: Equatable, Sendable {
    /// Fine; carries the name to store (whitespace collapsed).
    case accepted(String)
    case empty
    case tooLong
    /// Another one already has this name, ignoring case and accents.
    case duplicate

    var acceptedName: String? {
        if case .accepted(let name) = self { return name }
        return nil
    }
}
