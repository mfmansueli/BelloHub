//
//  CredentialKind.swift
//  BelloHub
//

/// A training or certificate she lists, or her professional registration (a council or city number), which has a
/// section of its own on the screen. Unknown kinds read as `training`.
enum CredentialKind: String, PersistedEnum {
    case training
    case registration

    static let fallback = CredentialKind.training
}
