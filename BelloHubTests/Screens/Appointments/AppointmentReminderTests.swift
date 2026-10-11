//
//  AppointmentReminderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The visit's reminder line (3.2, routine-a item 6): an opened chat is never "sent".
@Suite("AppointmentReminder")
struct AppointmentReminderTests {
    @Test("Nothing yet, then the chat opened, then her own mark, then the client's confirmation")
    func states() {
        var visit = makeAppointment(clientID: UUID(), daysFromNow: 1, status: .booked)
        #expect(AppointmentReminder.make(for: visit) == .notSent)
        visit.reminderSentAt = TestClock.now
        #expect(AppointmentReminder.make(for: visit) == .waiting(.conversationOpened(at: TestClock.now)))
        visit.reminderMarkedSentAt = TestClock.days(1)
        #expect(AppointmentReminder.make(for: visit) == .waiting(.markedSentByHer(at: TestClock.days(1))))
        visit.clientConfirmedAt = TestClock.days(1)
        #expect(AppointmentReminder.make(for: visit) == .confirmed(at: TestClock.days(1)))
    }

    @Test("A visit that no longer holds a time has no reminder line")
    func cancelled() {
        var visit = makeAppointment(clientID: UUID(), daysFromNow: 1, status: .cancelled)
        visit.reminderSentAt = TestClock.now
        #expect(AppointmentReminder.make(for: visit) == .notSent)
    }
}
