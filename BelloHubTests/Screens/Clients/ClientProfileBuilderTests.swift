//
//  ClientProfileBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientProfileBuilder")
struct ClientProfileBuilderTests {
    private let calendar = TestClock.calendar()
    private let client = makeListedClient(name: "Ana Costa")

    private func snapshot(
        appointments: [Appointment] = [], plans: [SessionPlan] = [], forms: [HealthForm] = [],
        consents: [Consent] = []
    ) -> ClientProfileSnapshot {
        ClientProfileBuilder.make(
            ClientProfileBuilder.Input(
                client: client, appointments: appointments, plans: plans, forms: forms, consents: consents
            ),
            now: TestClock.now, calendar: calendar
        )
    }

    private func plan(_ name: String, total: Int = 6, started days: Int = -100) -> SessionPlan {
        SessionPlan(
            id: UUID(), clientID: client.id, name: name, totalSessions: total, intervalWeeks: 4,
            startDate: TestClock.days(days), remindToRebook: true
        )
    }

    @Test("The last visit is the latest completed one; the next is the soonest that still holds time")
    func lastAndNext() {
        let appointments = [
            makeAppointment(clientID: client.id, daysFromNow: -60, serviceName: "Old"),
            makeAppointment(clientID: client.id, daysFromNow: -20, serviceName: "Latest"),
            makeAppointment(clientID: client.id, daysFromNow: -2, status: .cancelled, serviceName: "Cancelled"),
            makeAppointment(clientID: client.id, daysFromNow: 9, status: .booked, serviceName: "Later"),
            makeAppointment(clientID: client.id, daysFromNow: 3, status: .confirmed, serviceName: "Soon"),
            makeAppointment(clientID: UUID(), daysFromNow: 1, status: .booked, serviceName: "Someone else")
        ]

        let result = snapshot(appointments: appointments)

        #expect(result.lastVisit?.serviceName == "Latest")
        #expect(result.nextAppointment?.serviceName == "Soon")
    }

    @Test("A client with no history has no last visit and no next appointment")
    func emptyHistory() {
        let result = snapshot()

        #expect(result.lastVisit == nil && result.nextAppointment == nil && result.plan == nil)
        #expect(result.habits.visits == 0)
        #expect(result.health == .notFilledIn)
    }

    @Test("The habits are HabitsCalculator's, for this client only")
    func habitsComeFromTheCalculator() {
        let appointments = (0..<4).map { makeAppointment(clientID: client.id, daysFromNow: -80 + $0 * 14) }
            + [makeAppointment(clientID: UUID(), daysFromNow: -5)]

        let result = snapshot(appointments: appointments)

        #expect(result.habits == HabitsCalculator.habits(
            for: client.id, appointments: appointments, now: TestClock.now, calendar: calendar
        ))
        #expect(result.habits.visits == 4)
    }

    @Test("The plan shown is the most recent one that still has sessions to go")
    func activePlan() {
        let finished = plan("Finished", total: 1, started: -30)
        let running = plan("Skin barrier repair", total: 6, started: -100)
        let oldRunning = plan("Older", total: 6, started: -200)
        let done = makeAppointment(clientID: client.id, daysFromNow: -20, sessionPlanID: finished.id)

        let result = snapshot(appointments: [done], plans: [oldRunning, finished, running])

        #expect(result.plan?.plan.name == "Skin barrier repair")
        #expect(result.plan?.progress.currentSessionNumber == 1)
    }

    @Test("A plan whose sessions are all done is not shown")
    func finishedPlanIsHidden() {
        let finished = plan("Finished", total: 1)
        let done = makeAppointment(clientID: client.id, daysFromNow: -20, sessionPlanID: finished.id)

        #expect(snapshot(appointments: [done], plans: [finished]).plan == nil)
    }

    // MARK: - Health line

    @Test("The health line shows the most recent signature of a form or a consent")
    func healthSummary() {
        let form = HealthForm(
            id: UUID(), clientID: client.id, formVersion: 1, filledBy: .client, isForMinor: false,
            signedAt: TestClock.days(-40), importedFromItemID: nil, answers: [:], signatureImage: nil,
            guardianName: nil, minorName: nil
        )
        let consent = Consent(
            id: UUID(), clientID: client.id, kind: .treatment, signedAt: TestClock.days(-10), textVersion: "1",
            localeID: "en", typedSignature: nil, signatureImage: nil
        )

        #expect(ClientHealthSummary.make(forms: [form], consents: []) == .signed(TestClock.days(-40)))
        #expect(ClientHealthSummary.make(forms: [form], consents: [consent]) == .signed(TestClock.days(-10)))
        #expect(ClientHealthSummary.make(forms: [], consents: []) == .notFilledIn)
    }

    // MARK: - Chips

    @Test("The labels under her name: tags first, then what the history and her settings say")
    func chips() {
        let vip = Tag(id: UUID(), name: "VIP", colorToken: "rose", position: 0)
        var stopped = makeListedClient(name: "Ana", tagIDs: [vip.id, UUID()])
        stopped.onlineBookingStopped = true
        stopped.isArchived = true
        let habits = HabitsCalculator.habits(
            for: stopped.id,
            appointments: (0..<4).map { makeAppointment(clientID: stopped.id, daysFromNow: -90 + $0) }
                + (0..<3).map { makeAppointment(clientID: stopped.id, daysFromNow: -40 + $0, status: .noShow) },
            now: TestClock.now, calendar: calendar
        )

        let chips = ClientProfileChip.chips(for: stopped, habits: habits, tagsByID: [vip.id: vip])

        #expect(chips == [.tag("VIP"), .cancelsOften, .noShows(3), .onlineBookingStopped, .archived])
    }

    @Test("A client with a clean history and no tags has no labels")
    func noChips() {
        let habits = HabitsCalculator.habits(for: client.id, appointments: [], now: TestClock.now, calendar: calendar)

        #expect(ClientProfileChip.chips(for: client, habits: habits, tagsByID: [:]).isEmpty)
    }
}
