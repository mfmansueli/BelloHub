//
//  CalendarVisitText.swift
//  BelloHub
//

import Foundation

/// How the calendar says a visit in words: the time span, the status, and the one sentence VoiceOver reads for a block
/// of the grid (client, service, day, time and status, so a dense week grid is as clear as the day view).
struct CalendarVisitText {
    let formatters: Formatters

    /// "09:00 – 10:15", written the locale's way.
    func span(_ appointment: Appointment) -> String {
        let style = Date.IntervalFormatStyle(
            locale: formatters.locale, calendar: formatters.calendar, timeZone: formatters.timeZone
        ).hour().minute()
        return (appointment.startsAt..<max(appointment.endsAt, appointment.startsAt)).formatted(style)
    }

    func statusTitle(_ status: AppointmentStatus) -> LocalizedStringResource {
        switch status {
        case .booked: LocalizedStringResource("calendar.visit.status.booked", defaultValue: "Booked")
        case .confirmed: LocalizedStringResource("calendar.visit.status.confirmed", defaultValue: "Confirmed")
        case .completed: LocalizedStringResource("calendar.visit.status.completed", defaultValue: "Completed")
        case .cancelled: LocalizedStringResource("calendar.visit.status.cancelled", defaultValue: "Cancelled")
        case .noShow: LocalizedStringResource("calendar.visit.status.noShow", defaultValue: "No-show")
        }
    }

    /// "Ana Costa, Brazilian Glow, Wednesday, September 30, 15:00 – 16:30, Confirmed".
    func accessibilityLabel(for appointment: Appointment, clientName: String) -> String {
        let name = clientName.isEmpty ? String(localized: LocalizedStringResource(
            "calendar.visit.unknownClient", defaultValue: "Client", locale: formatters.locale
        )) : clientName
        let status = String(localized: statusTitle(appointment.status).localized(in: formatters.locale))
        let day = formatters.weekdayDayMonth(appointment.startsAt)
        return String(localized: LocalizedStringResource(
            "calendar.visit.accessibility",
            defaultValue: "\(name), \(appointment.serviceName), \(day), \(span(appointment)), \(status)",
            locale: formatters.locale
        ))
    }

    /// What the free hour says to VoiceOver: "Add an appointment at 10:00".
    func addLabel(at date: Date) -> String {
        String(localized: LocalizedStringResource(
            "calendar.slot.add", defaultValue: "Add an appointment at \(formatters.time(date))",
            locale: formatters.locale
        ))
    }
}
