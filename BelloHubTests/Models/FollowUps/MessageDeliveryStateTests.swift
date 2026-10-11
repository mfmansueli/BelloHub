//
//  MessageDeliveryStateTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("MessageDeliveryState")
struct MessageDeliveryStateTests {
    @Test("A reminder: her mark wins over the opened chat, which wins over nothing")
    func reminder() {
        var visit = makeAppointment(clientID: UUID(), daysFromNow: 1, status: .booked)
        #expect(MessageDeliveryState.reminder(of: visit) == .readyToSend)
        visit.reminderSentAt = TestClock.now
        #expect(MessageDeliveryState.reminder(of: visit) == .conversationOpened(at: TestClock.now))
        visit.reminderMarkedSentAt = TestClock.days(1)
        #expect(MessageDeliveryState.reminder(of: visit) == .markedSentByHer(at: TestClock.days(1)))
    }

    @Test("A visit stored before the mark existed decodes with no mark")
    func decodesOldVisits() throws {
        let visit = makeAppointment(clientID: UUID(), daysFromNow: 1, status: .booked)
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(visit)) as? [String: Any])
        object.removeValue(forKey: "reminderMarkedSentAt")
        let old = try JSONDecoder().decode(Appointment.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.reminderMarkedSentAt == nil && old.id == visit.id)
    }

    @Test("Moving a visit clears both the opened chat and her mark")
    func rescheduleClears() {
        var visit = makeAppointment(clientID: UUID(), daysFromNow: 1, status: .booked)
        visit.reminderSentAt = TestClock.now
        visit.reminderMarkedSentAt = TestClock.now
        let moved = AppointmentTransitions.rescheduled(visit, to: TestClock.days(2), now: TestClock.now)
        #expect(MessageDeliveryState.reminder(of: moved) == .readyToSend)
    }
}
