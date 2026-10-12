//
//  ConsentKind.swift
//  BelloHub
//

/// The category of a `ConsentRecord` (D55): what the paper she keeps is about. A signed `photos` record is the one
/// rule the app reads from it (`PhotoConsentRules`); the others are for her own organization.
enum ConsentKind: String, PersistedEnum, Identifiable {
    /// Her own health questionnaire (anamnesis), filled in and signed with the client in person (D60).
    case healthForm
    case treatment
    case photos
    /// A parent or legal guardian signing for someone under 18 (D17).
    case guardian
    /// Anything else she asks her clients to sign, named by the record's label.
    case other

    var id: String { rawValue }

    static let fallback = ConsentKind.treatment
}
