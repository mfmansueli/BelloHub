//
//  EventKitCalendarAccess.swift
//  BelloHub
//

import EventKit

/// EventKit as `CalendarAccessProviding`: the only file that imports it. The limited-access flows of iOS 17 and later
/// (`writeOnly`) are reported honestly rather than treated as full access.
struct EventKitCalendarAccess: CalendarAccessProviding {
    func status() -> CalendarAccessStatus {
        Self.map(EKEventStore.authorizationStatus(for: .event))
    }

    func requestFullAccess() async -> CalendarAccessStatus {
        let store = EKEventStore()
        _ = try? await store.requestFullAccessToEvents()
        return status()
    }

    private static func map(_ status: EKAuthorizationStatus) -> CalendarAccessStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .fullAccess: .full
        case .writeOnly: .writeOnly
        default: .denied
        }
    }
}
