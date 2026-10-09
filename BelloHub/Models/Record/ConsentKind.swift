//
//  ConsentKind.swift
//  BelloHub
//

enum ConsentKind: String, PersistedEnum {
    case treatment
    case photos
    /// A parent or legal guardian consenting for a minor (D17). It is the treatment consent of someone under 18, on
    /// its own text (`consent-guardian`).
    case guardian

    static let fallback = ConsentKind.treatment
}
