//
//  UITestCalendarAccess.swift
//  BelloHub
//

#if DEBUG
import os

/// A calendar that grants full access without a dialog, so a UI test can connect Apple Calendar. DEBUG only.
final class UITestCalendarAccess: CalendarAccessProviding, Sendable {
    private let current = OSAllocatedUnfairLock(initialState: CalendarAccessStatus.notDetermined)

    func status() -> CalendarAccessStatus {
        current.withLock { $0 }
    }

    func requestFullAccess() async -> CalendarAccessStatus {
        current.withLock { $0 = .full }
        return .full
    }
}
#endif
