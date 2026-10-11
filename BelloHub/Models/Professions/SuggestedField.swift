//
//  SuggestedField.swift
//  BelloHub
//

/// A field of the treatment record the catalog suggests for a profession.
struct SuggestedField: Identifiable, Hashable, Codable, Sendable {
    let key: String
    let name: String
    /// Whether it starts switched on.
    let on: Bool

    var id: String { key }
}
