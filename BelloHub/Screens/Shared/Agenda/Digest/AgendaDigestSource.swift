//
//  AgendaDigestSource.swift
//  BelloHub
//

import Foundation

/// Where a screen's ViewModel gets its `AgendaDigest`: the raw data of `AgendaDigestService`, her availability, her
/// notification prefs and the business days, put through the pure rules at the moment the screen asks. Reading the
/// service's properties inside the call is what makes a SwiftUI body update when the vault pushes a change.
@MainActor
struct AgendaDigestSource {
    let service: AgendaDigestService
    let bookingSetup: BookingSetupService
    let prefs: any NotificationPrefsStoring
    let days: CalendarDays

    init(
        service: AgendaDigestService, bookingSetup: BookingSetupService, settings: CalendarSettings,
        prefs: any NotificationPrefsStoring = DefaultsNotificationPrefsStore()
    ) {
        self.service = service
        self.bookingSetup = bookingSetup
        self.prefs = prefs
        days = CalendarDays(timeZone: settings.timeZone, firstWeekday: settings.firstWeekday)
    }

    func digest(now: Date) -> AgendaDigest {
        AgendaDigest.make(
            AgendaDigest.Input(
                appointments: service.appointments, clients: service.clients, services: service.services,
                blocks: service.blocks, availability: bookingSetup.availability.inTimeZone(days.calendar.timeZone),
                prefs: prefs.load(), now: now
            ),
            days: days
        )
    }

    /// The state the screen is in, from the service's own flags. `isEmpty` is the screen's own judgment.
    func phase(isEmpty: Bool) -> ScreenPhase {
        ScreenPhase.resolve(isLoading: service.isLoading, errorMessage: service.errorMessage, isEmpty: isEmpty)
    }
}
