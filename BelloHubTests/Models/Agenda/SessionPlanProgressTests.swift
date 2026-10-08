//
//  SessionPlanProgressTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("SessionPlanProgress")
struct SessionPlanProgressTests {
    private let calendar = TestClock.calendar()
    private let clientID = UUID()

    /// The prototype's plan: "Skin barrier repair", 6 sessions every 4 weeks, today is session 3.
    private func plan() -> SessionPlan {
        SessionPlan(id: UUID(), clientID: clientID, name: "Skin barrier repair", totalSessions: 6, intervalWeeks: 4,
                    startDate: TestClock.days(-56), remindToRebook: true)
    }

    private func done(_ plan: SessionPlan, daysAgo: [Int]) -> [Appointment] {
        daysAgo.map { makeAppointment(clientID: clientID, daysFromNow: -$0, sessionPlanID: plan.id) }
    }

    @Test("Two sessions done means session 3 of 6 is current")
    func sessionThreeOfSix() {
        let plan = plan()
        let visits = done(plan, daysAgo: [56, 28])
        let progress = SessionPlanProgress.make(plan: plan, appointments: visits, calendar: calendar)

        #expect(progress.completedSessions == 2)
        #expect(progress.currentSessionNumber == 3)
        #expect(!progress.isFinished)
        #expect(progress.steps.map(\.state) == [.done, .done, .current, .upcoming, .upcoming, .upcoming])
    }

    @Test("The next session is suggested the plan's interval after the last one done")
    func nextSuggested() {
        let plan = plan()
        let visits = done(plan, daysAgo: [56, 28])
        let progress = SessionPlanProgress.make(plan: plan, appointments: visits, calendar: calendar)

        // Visits are at 11:00 and the reference "now" is 12:00, so compare days, not instants.
        #expect(progress.nextSuggestedDate.map { calendar.isDate($0, inSameDayAs: TestClock.days(0)) } == true)
        #expect(progress.steps[3].date.map { calendar.isDate($0, inSameDayAs: TestClock.days(28)) } == true)
    }

    @Test("Before any session the first one is suggested on the plan's start date")
    func beforeTheFirst() {
        let plan = plan()
        let progress = SessionPlanProgress.make(plan: plan, appointments: [], calendar: calendar)

        #expect(progress.currentSessionNumber == 1)
        #expect(progress.nextSuggestedDate == plan.startDate)
    }

    @Test("All sessions done finishes the plan: no current session, no next date")
    func finished() {
        let plan = plan()
        let visits = done(plan, daysAgo: [150, 125, 100, 75, 50, 25])
        let progress = SessionPlanProgress.make(plan: plan, appointments: visits, calendar: calendar)

        #expect(progress.isFinished)
        #expect(progress.currentSessionNumber == nil)
        #expect(progress.nextSuggestedDate == nil)
    }

    @Test("Only completed visits of this plan count")
    func onlyThisPlanAndCompleted() {
        let plan = plan()
        let cancelled = makeAppointment(clientID: clientID, daysFromNow: -20, status: .cancelled, cancelledBy: .client,
                                        sessionPlanID: plan.id)
        let otherPlan = makeAppointment(clientID: clientID, daysFromNow: -10, sessionPlanID: UUID())
        let progress = SessionPlanProgress.make(plan: plan, appointments: [cancelled, otherPlan], calendar: calendar)

        #expect(progress.completedSessions == 0)
    }

    @Test("More visits than sessions never go past the total")
    func capped() {
        let plan = SessionPlan(id: UUID(), clientID: clientID, name: "Short", totalSessions: 2, intervalWeeks: 2,
                               startDate: TestClock.days(-60), remindToRebook: false)
        let progress = SessionPlanProgress.make(plan: plan, appointments: done(plan, daysAgo: [40, 30, 20, 10]),
                                                calendar: calendar)

        #expect(progress.completedSessions == 2)
        #expect(progress.isFinished)
    }
}
