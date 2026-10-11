//
//  LocalNotificationKind.swift
//  BelloHub
//

import Foundation

/// The notifications the iPhone schedules for the professional on its own (no server involved).
enum LocalNotificationKind: String, CaseIterable, Sendable {
    case nextVisit
    case birthday
    case dailySummary
    case remindersReady

    /// What quiet hours decide on (`QuietHours`).
    var alertKind: AlertKind {
        switch self {
        case .nextVisit: .nextVisit
        case .birthday: .birthday
        case .dailySummary: .dailySummary
        case .remindersReady: .remindersReady
        }
    }

    /// Groups the kind on the lock screen.
    var threadID: String { "bello.\(rawValue)" }
}
