//
//  PlannedNotification.swift
//  BelloHub
//

import Foundation

/// A local notification the planner decided on. Its text is generic by construction: `NotificationTexts` has no way to
/// receive a client's or a service's name (docs/06-PRIVACY-SECURITY.md section 8).
struct PlannedNotification: Equatable, Identifiable, Sendable {
    /// Every identifier starts with this, so the scheduler replaces only its own notifications.
    static let identifierPrefix = "bello."

    let id: String
    let kind: LocalNotificationKind
    let fireDate: Date
    let title: String
    let body: String
}
