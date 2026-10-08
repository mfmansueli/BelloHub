//
//  BiometricResult.swift
//  BelloHub
//

/// The outcome of one unlock attempt.
enum BiometricResult: Equatable, Sendable {
    case success
    /// She dismissed the system sheet. Nothing to explain.
    case cancelled
    /// The face or passcode did not match.
    case failed
    /// The phone has no passcode, so there is nothing to ask for. The lock cannot protect anything.
    case unavailable
}
