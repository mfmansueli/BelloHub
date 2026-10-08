//
//  AuthError.swift
//  BelloHub
//

/// Why phone sign-in failed, in terms the screen can explain. A provider maps its own errors to these, so nothing
/// above `Managers/Session` ever sees an SDK error type.
enum AuthError: Error, Equatable, Sendable {
    /// The phone number was refused.
    case invalidPhone
    /// The six digits do not match, or the code expired.
    case invalidCode
    /// Too many codes or too many wrong tries: wait before trying again.
    case tooManyAttempts
    /// No connection, or the service did not answer.
    case network
    /// This build has no sign-in provider yet (the Firebase provider arrives in S8).
    case unavailable
}
