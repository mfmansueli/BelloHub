//
//  HealthOption.swift
//  BelloHub
//

/// One choice of a `choices` question. The `key` is stable across languages and is what an answer stores; the `name`
/// is only what each language shows.
struct HealthOption: Identifiable, Hashable, Sendable {
    /// The key every question with a "None" option shares; selecting it clears the other choices.
    static let noneKey = "none"

    let key: String
    let name: String

    var id: String { key }
}
