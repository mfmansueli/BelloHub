//
//  RegionCatalog+Bundle.swift
//  BelloHub
//

import Foundation

extension RegionCatalog {
    enum LoadError: Error {
        case missingResource
    }

    /// Loads the shipped `regions.json`. Reading the bundle is IO, which is why this is in `Managers/`.
    static func loadBundled(in bundle: Bundle = .main) throws -> RegionCatalog {
        guard let url = bundle.url(forResource: "regions", withExtension: "json") else {
            throw LoadError.missingResource
        }
        let presets = try JSONDecoder().decode([RegionPreset].self, from: Data(contentsOf: url))
        return RegionCatalog(presets: presets)
    }
}
