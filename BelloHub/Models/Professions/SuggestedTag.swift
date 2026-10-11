//
//  SuggestedTag.swift
//  BelloHub
//

/// A client tag the catalog suggests. Tags are private labels the professional reads; they are stored in the clear,
/// so the catalog never suggests a tag that states a diagnosis.
struct SuggestedTag: Identifiable, Hashable, Codable, Sendable {
    let key: String
    let name: String
    /// A semantic color token (`rose`, `sage`, `peach`, `sand`), never a hex value.
    let color: String
    let selected: Bool

    var id: String { key }
}
