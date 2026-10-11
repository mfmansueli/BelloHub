//
//  BiometricAuthenticating.swift
//  BelloHub
//

/// The system's Face ID or passcode check, behind a protocol so tests drive the lock without a real face.
protocol BiometricAuthenticating: Sendable {
    var kind: BiometryKind { get }
    /// Shows the system sheet: Face ID first, the passcode when it fails or she asks for it.
    func authenticate(reason: String) async -> BiometricResult
}
