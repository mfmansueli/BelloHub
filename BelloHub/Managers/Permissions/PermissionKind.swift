//
//  PermissionKind.swift
//  BelloHub
//

/// The system permissions the onboarding explains one by one. The order is the order of the screens.
enum PermissionKind: String, CaseIterable, Identifiable, Sendable {
    case microphone
    case notifications
    case camera
    case contacts

    var id: String { rawValue }
}
