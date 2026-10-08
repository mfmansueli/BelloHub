//
//  AuthUser.swift
//  BelloHub
//

/// The signed-in professional as the app knows her: an opaque id and the phone she signed in with. Nothing else
/// about her comes from the auth provider.
struct AuthUser: Equatable, Hashable, Codable, Sendable {
    let id: String
    /// International format, plus sign and digits only.
    let phoneE164: String
}
