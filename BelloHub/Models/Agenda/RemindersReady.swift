//
//  RemindersReady.swift
//  BelloHub
//

import Foundation

/// The "Reminders ready" queue (D31, docs/10-WEB-BOOKING.md section 9): the visits whose client she can remind now, by
/// WhatsApp, with one tap each. The app never sends by itself, so this only decides **who is on the list and when**;
/// the message is opened by `MessageService`. Pure: `now`, the calendar (so the business time zone) and the prefs are
/// inputs, and the evening-before moment is tested across daylight-saving changes.
enum RemindersReady {
    /// A visit on the list. `openedAt` is set once she opened the chat (`Appointment.reminderSentAt`).
    struct Item: Equatable, Identifiable, Sendable {
        let appointment: Appointment
        let client: Client
        var openedAt: Date? { appointment.reminderSentAt }
        var id: UUID { appointment.id }
    }

    /// Whether a reminder makes sense for this visit and client at all, whatever the time: the visit still holds a
    /// time, the client has not confirmed, she can be reached (a phone number, reminders not stopped, not archived).
    static func isRemindable(_ appointment: Appointment, client: Client?) -> Bool {
        guard let client, appointment.status.holdsTime, appointment.clientConfirmedAt == nil,
              !client.isArchived, client.remindersEnabled,
              let phone = client.phoneE164, !phone.isEmpty else { return false }
        return true
    }

    /// When the reminder of a visit becomes ready: `prefs.reminderTimeMinutes` on the evening before the visit's day,
    /// in the business time zone. A wall-clock time that does not exist that day moves to the next valid one.
    static func moment(forVisitAt start: Date, prefs: NotificationPrefs, calendar: Calendar) -> Date? {
        let dayStart = calendar.startOfDay(for: start)
        guard let before = calendar.date(byAdding: .day, value: -1, to: dayStart) else { return nil }
        return calendar.date(
            bySettingHour: prefs.reminderTimeMinutes / 60, minute: prefs.reminderTimeMinutes % 60, second: 0,
            of: before, matchingPolicy: .nextTime
        )
    }

    /// Visits that are ready now: reminders on, the evening-before moment has passed and the visit is still ahead.
    /// Not yet opened first, soonest first; the ones she already opened follow, so the row can say "Opened".
    static func items(
        appointments: [Appointment], clients: [Client], prefs: NotificationPrefs, now: Date, calendar: Calendar
    ) -> [Item] {
        guard prefs.clientRemindersEnabled else { return [] }
        let byID = Dictionary(clients.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ready = appointments.compactMap { appointment -> Item? in
            guard appointment.startsAt > now, let client = byID[appointment.clientID],
                  isRemindable(appointment, client: client),
                  let moment = moment(forVisitAt: appointment.startsAt, prefs: prefs, calendar: calendar),
                  moment <= now else { return nil }
            return Item(appointment: appointment, client: client)
        }
        return ready.sorted {
            let leftOpened = $0.openedAt != nil
            let rightOpened = $1.openedAt != nil
            if leftOpened != rightOpened { return !leftOpened }
            return $0.appointment.startsAt < $1.appointment.startsAt
        }
    }
}
