//
//  VaultStorable+Catalog.swift
//  BelloHub
//

import Foundation

// How the add-ons, products and credentials are stored (docs/05-DATA-MODEL.md section 1). None of them is clinical:
// they are what she offers and shows, so nothing is sealed. Kept apart from `VaultStorable+Models.swift`.

extension AddOn: VaultStorable {
    static var kind: VaultKind { .addOn }

    var index: VaultIndex {
        VaultIndex(textKey: name, statusRaw: isOffered ? "offered" : "hidden")
    }
}

extension Product: VaultStorable {
    static var kind: VaultKind { .product }

    var index: VaultIndex {
        VaultIndex(textKey: name, statusRaw: sharedWithClient ? "shared" : "private")
    }
}

extension Credential: VaultStorable {
    static var kind: VaultKind { .credential }

    var index: VaultIndex {
        VaultIndex(textKey: title, statusRaw: kind.rawValue)
    }
}
