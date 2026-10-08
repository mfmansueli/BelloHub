//
//  PermissionProviding.swift
//  BelloHub
//

/// The system's permission dialogs behind a protocol, so onboarding is tested without showing one.
protocol PermissionProviding: Sendable {
    func status(of kind: PermissionKind) async -> PermissionStatus
    /// Shows the system dialog (once: after an answer the system never asks again) and returns the answer.
    func request(_ kind: PermissionKind) async -> PermissionStatus
}
