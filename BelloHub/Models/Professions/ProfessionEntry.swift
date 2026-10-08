//
//  ProfessionEntry.swift
//  BelloHub
//

/// What the catalog knows about one profession in one language.
struct ProfessionEntry: Identifiable, Hashable, Codable, Sendable {
    let id: ProfessionID
    /// "Esthetician", as a label on a choice.
    let name: String
    /// "estheticians", lowercase, for sentences such as "Suggested for estheticians".
    let plural: String
    let services: [SuggestedService]
    let tags: [SuggestedTag]
    let fields: [SuggestedField]
    /// Intake items that start switched on for this profession.
    let intake: [IntakeItem]
}
