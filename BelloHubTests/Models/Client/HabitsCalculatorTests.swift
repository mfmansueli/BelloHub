//
//  HabitsCalculatorTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("HabitsCalculator")
struct HabitsCalculatorTests {
    private let calendar = TestClock.calendar()
    private let clientID = UUID()

    private func habits(_ appointments: [Appointment]) -> ClientHabits {
        HabitsCalculator.habits(for: clientID, appointments: appointments, now: TestClock.now, calendar: calendar)
    }

    private func completed(_ count: Int, startingAt day: Int = -100, every step: Int = 7) -> [Appointment] {
        (0..<count).map { makeAppointment(clientID: clientID, daysFromNow: day + $0 * step) }
    }

    /// The prototype's Beatriz: 6 visits, 3 cancelled (2 late), 1 no-show, 40 % of the last ten.
    private func beatriz() -> [Appointment] {
        func cancelled(_ day: Int, late: Bool) -> Appointment {
            makeAppointment(clientID: clientID, daysFromNow: day, status: .cancelled, cancelledBy: .client,
                            isLate: late)
        }
        return completed(6, startingAt: -120, every: 10)
            + [cancelled(-60, late: true), cancelled(-50, late: true), cancelled(-40, late: false),
               makeAppointment(clientID: clientID, daysFromNow: -30, status: .noShow)]
    }

    @Test("The prototype's Beatriz: 40 percent, cancels often, 2 late cancellations")
    func beatrizFromThePrototype() {
        let result = habits(beatriz())

        #expect(result.visits == 6)
        #expect(result.cancelled == 3)
        #expect(result.noShows == 1)
        #expect(result.lateCancellations == 2)
        #expect(result.cancellationRate == 0.4)
        #expect(result.cancelsOften)
    }

    @Test("The prototype's Ana: two visits, no rate, back every ~6 weeks")
    func anaFromThePrototype() {
        let result = habits(completed(2, startingAt: -90, every: 42))

        #expect(result.visits == 2)
        #expect(result.cancellationRate == nil)
        #expect(!result.cancelsOften)
        #expect(result.returnsEveryWeeks == 6)
    }

    @Test("The rate appears at exactly four completed visits, not at three", arguments: [(3, false), (4, true)])
    func rateThreshold(visits: Int, shown: Bool) {
        let appointments = completed(visits) + [
            makeAppointment(clientID: clientID, daysFromNow: -10, status: .noShow),
            makeAppointment(clientID: clientID, daysFromNow: -9, status: .noShow)
        ]

        #expect((habits(appointments).cancellationRate != nil) == shown)
        #expect(habits(appointments).cancelsOften == shown)
    }

    @Test("Three missed of the last ten is exactly 30 percent and counts as cancelling often; two does not")
    func thirtyPercentBoundary() {
        func attempt(missed: Int) -> ClientHabits {
            habits(completed(10 - missed, startingAt: -100, every: 5) + (0..<missed).map {
                makeAppointment(clientID: clientID, daysFromNow: -3 - $0, status: .noShow)
            })
        }

        #expect(attempt(missed: 3).cancellationRate == 0.3)
        #expect(attempt(missed: 3).cancelsOften)
        #expect(attempt(missed: 2).cancellationRate == 0.2)
        #expect(!attempt(missed: 2).cancelsOften)
    }

    @Test("A cancellation by the professional never counts against the client")
    func professionalCancellationIsExcluded() {
        let appointments = completed(4) + [
            makeAppointment(clientID: clientID, daysFromNow: -20, status: .cancelled, cancelledBy: .professional),
            makeAppointment(clientID: clientID, daysFromNow: -15, status: .cancelled, cancelledBy: .professional)
        ]
        let result = habits(appointments)

        #expect(result.cancelled == 0)
        #expect(result.cancellationRate == 0)
        #expect(!result.cancelsOften)
    }

    @Test("A forgiven no-show is left out of the count and of the rate")
    func forgivenNoShowIsExcluded() {
        let forgiven = makeAppointment(clientID: clientID, daysFromNow: -5, status: .noShow, forgiven: true)
        let appointments = completed(4) + [forgiven]
        let result = habits(appointments)

        #expect(result.noShows == 0)
        #expect(result.cancellationRate == 0)
    }

    @Test("Only the ten most recent past appointments count")
    func windowOfTen() {
        // Five old no-shows, then ten completed visits: the old ones fall outside the window.
        let old = (0..<5).map { makeAppointment(clientID: clientID, daysFromNow: -300 + $0, status: .noShow) }
        let result = habits(old + completed(10, startingAt: -100, every: 7))

        #expect(result.cancellationRate == 0)
        #expect(result.noShows == 5)
    }

    @Test("Future and still-booked appointments are not past appointments")
    func futureIsNotCounted() {
        let appointments = completed(4) + [makeAppointment(clientID: clientID, daysFromNow: 5, status: .booked)]

        #expect(habits(appointments).cancellationRate == 0)
    }

    @Test("Another client's appointments are ignored")
    func otherClientsIgnored() {
        let stranger = makeAppointment(clientID: UUID(), daysFromNow: -3, status: .noShow)

        #expect(habits(completed(4) + [stranger]).noShows == 0)
    }

    @Test("The return rhythm is the median gap, in whole weeks")
    func medianReturn() {
        // Gaps of 14, 14 and 70 days: the median is 14 days, 2 weeks.
        let days = [-200, -186, -172, -102]
        let appointments = days.map { makeAppointment(clientID: clientID, daysFromNow: $0) }

        #expect(habits(appointments).returnsEveryWeeks == 2)
    }

    @Test("With an even number of gaps the median is the mean of the two middle ones")
    func evenMedian() {
        // Gaps of 14 and 28: the median is 21 days, 3 weeks.
        let appointments = [-100, -86, -58].map { makeAppointment(clientID: clientID, daysFromNow: $0) }

        #expect(habits(appointments).returnsEveryWeeks == 3)
    }

    @Test("The usual period follows the business time zone",
          arguments: [(9, DayPeriod.morning), (14, .afternoon), (18, .evening)])
    func usualPeriod(hour: Int, expected: DayPeriod) {
        let appointments = (0..<3).map { makeAppointment(clientID: clientID, daysFromNow: -10 - $0, hour: hour) }

        #expect(habits(appointments).usualPeriod == expected)
    }

    @Test("The most booked service wins, and the more recent one wins a tie")
    func mostBooked() {
        let mixed = [
            makeAppointment(clientID: clientID, daysFromNow: -30, serviceName: "Deep Cleansing"),
            makeAppointment(clientID: clientID, daysFromNow: -20, serviceName: "Glow Facial"),
            makeAppointment(clientID: clientID, daysFromNow: -10, serviceName: "Glow Facial")
        ]
        let tied = [
            makeAppointment(clientID: clientID, daysFromNow: -30, serviceName: "Deep Cleansing"),
            makeAppointment(clientID: clientID, daysFromNow: -10, serviceName: "Glow Facial")
        ]

        #expect(habits(mixed).mostBookedService == "Glow Facial")
        #expect(habits(tied).mostBookedService == "Glow Facial")
    }

    @Test("A client with no history has empty habits")
    func empty() {
        let result = habits([])

        #expect(result.visits == 0)
        #expect(result.lastVisit == nil)
        #expect(result.returnsEveryWeeks == nil)
        #expect(result.usualPeriod == nil)
        #expect(result.mostBookedService == nil)
        #expect(result.cancellationRate == nil)
    }

    @Test("Reminder response time averages the days between a reminder and the confirmation")
    func reminderResponse() {
        var first = makeAppointment(clientID: clientID, daysFromNow: -10)
        first.reminderSentAt = first.startsAt.addingTimeInterval(-3 * 86_400)
        first.clientConfirmedAt = first.startsAt.addingTimeInterval(-2 * 86_400)
        var second = makeAppointment(clientID: clientID, daysFromNow: -20)
        second.reminderSentAt = second.startsAt.addingTimeInterval(-3 * 86_400)
        second.clientConfirmedAt = second.startsAt.addingTimeInterval(-3 * 86_400 + 3 * 86_400)

        #expect(habits([first, second]).reminderResponseDays == 2)
        #expect(habits(completed(2)).reminderResponseDays == nil)
    }
}
