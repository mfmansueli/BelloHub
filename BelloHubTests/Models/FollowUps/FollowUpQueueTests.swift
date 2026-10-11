//
//  FollowUpQueueTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The one follow-up queue (routine-a items 5, 6, 7 and 12), built from fixed data at `TestClock.now`
/// (Thursday 2026-10-01, 12:00 in São Paulo).
@Suite("FollowUpQueue")
struct FollowUpQueueTests {
    private let days = CalendarDays(timeZone: TestClock.saoPaulo, firstWeekday: 2)

    private func queue(
        _ visits: [Appointment], clients: [Client], services: [Service] = [], logs: [MessageLog] = [],
        decisions: [String: FollowUpDecision] = [:], closings: [VisitClosing] = [], now: Date = TestClock.now,
        prefs: NotificationPrefs = .standard
    ) -> FollowUpQueue {
        let digest = AgendaDigest.make(
            AgendaDigest.Input(
                appointments: visits, clients: clients, services: services, blocks: [],
                availability: makeAvailability(), prefs: prefs, now: now
            ),
            days: days
        )
        return FollowUpQueue.make(FollowUpQueue.Input(
            digest: digest, appointments: visits, clients: clients, messageLogs: logs, decisions: decisions,
            closings: closings, now: now, calendar: days.calendar
        ))
    }

    private func reachable(_ name: String, birthday: Birthday? = nil) -> Client {
        Client(name: name, phoneE164: "+5511955550001", birthday: birthday, createdAt: TestClock.days(-300))
    }

    private func completed(_ client: Client, _ service: Service, daysAgo: Int) -> Appointment {
        makeAppointment(clientID: client.id, daysFromNow: -daysAgo, serviceID: service.id)
    }

    @Test("A client due for a return and away for months is one row with both reasons, the return first")
    func grouping() {
        let glow = makeService(followUpWeeks: 6)
        let ana = reachable("Ana Costa")
        let result = queue([completed(ana, glow, daysAgo: 90)], clients: [ana], services: [glow])

        #expect(result.rows.count == 1)
        #expect(result.rows[0].items.map(\.kind) == [.returnDue, .notBack])
        #expect(result.count(.returns) == 1 && result.count(.notBack) == 1 && result.count(.all) == 1)
        #expect(result.rows(.notBack).first?.items.map(\.kind) == [.notBack])
    }

    @Test("The return reason names the service and its usual interval, from her own data")
    func returnReason() throws {
        let glow = makeService(followUpWeeks: 6)
        let ana = reachable("Ana Costa")
        let item = try #require(queue([completed(ana, glow, daysAgo: 50)], clients: [ana], services: [glow])
            .rows.first?.primary)

        guard case let .returnDue(service, weeks, _) = item.reason else {
            Issue.record("not a return: \(item.reason)")
            return
        }
        #expect(service == "Glow Facial" && weeks == 6)
        #expect(item.delivery == .readyToSend)
    }

    @Test("Someone with a visit booked is not suggested a return")
    func bookedIsNotDue() {
        let glow = makeService(followUpWeeks: 4)
        let ana = reachable("Ana Costa")
        let booked = makeAppointment(clientID: ana.id, daysFromNow: 3, status: .booked, serviceID: glow.id)
        #expect(queue([completed(ana, glow, daysAgo: 50), booked], clients: [ana], services: [glow]).isEmpty)
    }

    @Test("A visit of today or yesterday suggests a check-in; an older one does not")
    func postVisit() {
        let glow = makeService(followUpWeeks: nil)
        let ana = reachable("Ana Costa")
        let bea = reachable("Beatriz Lima")
        let cris = reachable("Cristina Alves")
        let today = makeAppointment(clientID: ana.id, daysFromNow: 0, hour: 9, serviceID: glow.id)
        let yesterday = completed(bea, glow, daysAgo: 1)
        let older = completed(cris, glow, daysAgo: 3)
        let result = queue([today, yesterday, older], clients: [ana, bea, cris], services: [glow])

        #expect(Set(result.rows(.visits).map(\.client.id)) == [ana.id, bea.id])
    }

    @Test("A visit left with Finish later is listed until every step is settled, and cannot be dismissed")
    func unfinished() throws {
        let ana = reachable("Ana Costa")
        var closing = VisitClosing(
            id: UUID(), clientID: ana.id, serviceName: "Glow Facial", recordCreatedAt: TestClock.days(-1)
        )
        closing.isDeferred = true
        closing.settled = [.photos]
        let decisions = ["visit:\(closing.id)": FollowUpDecision(dismissedAt: TestClock.now)]
        let built = queue([], clients: [ana], decisions: decisions, closings: [closing])
        let item = try #require(built.rows.first?.primary)

        #expect(item.kind == .unfinishedVisit && item.recordID == closing.id)
        #expect(item.reason == .unfinishedVisit(serviceName: "Glow Facial", openSteps: [.aftercare, .nextVisit]))

        closing.settled = Set(VisitClosing.Step.allCases)
        #expect(queue([], clients: [ana], closings: [closing]).isEmpty)
    }

    @Test("Snoozed until next week it waits aside, and comes back when the week is over")
    func snooze() {
        let glow = makeService(followUpWeeks: 4)
        let ana = reachable("Ana Costa")
        let visit = completed(ana, glow, daysAgo: 40)
        let occurrence = "returnDue:\(ana.id):\(Int(visit.startsAt.timeIntervalSince1970))"
        let decisions = [occurrence: FollowUpDecision(snoozedUntil: TestClock.days(7))]

        let now = queue([visit], clients: [ana], services: [glow], decisions: decisions)
        #expect(now.rows.isEmpty && now.setAside.count == 1)

        let later = queue([visit], clients: [ana], services: [glow], decisions: decisions, now: TestClock.days(8))
        #expect(later.rows.count == 1)
    }

    @Test("A new visit is a new occurrence: an old dismissal does not hide the next return")
    func newOccurrence() {
        let glow = makeService(followUpWeeks: 4)
        let ana = reachable("Ana Costa")
        let old = completed(ana, glow, daysAgo: 120)
        let recent = completed(ana, glow, daysAgo: 40)
        let decisions = ["returnDue:\(ana.id):\(Int(old.startsAt.timeIntervalSince1970))":
            FollowUpDecision(dismissedAt: TestClock.days(-60))]

        #expect(queue([old, recent], clients: [ana], services: [glow], decisions: decisions).count(.returns) == 1)
    }

    @Test("A chat opened after the item was due reads as opened; her mark reads as hers")
    func delivery() throws {
        let glow = makeService(followUpWeeks: 4)
        let ana = reachable("Ana Costa")
        let visit = completed(ana, glow, daysAgo: 40)
        let opened = MessageLog(
            id: UUID(), clientID: ana.id, channel: .whatsapp, template: "followUp", openedAt: TestClock.days(-1)
        )
        let stale = MessageLog(
            id: UUID(), clientID: ana.id, channel: .whatsapp, template: "followUp", openedAt: TestClock.days(-39)
        )
        let item = try #require(queue([visit], clients: [ana], services: [glow], logs: [opened, stale])
            .rows.first?.primary)
        #expect(item.delivery == .conversationOpened(at: TestClock.days(-1)))

        let occurrence = item.occurrence
        let marked = queue(
            [visit], clients: [ana], services: [glow], logs: [opened],
            decisions: [occurrence: FollowUpDecision(snoozedUntil: TestClock.days(14), markedSentAt: TestClock.now)]
        )
        #expect(marked.setAside.first?.primary.delivery == .markedSentByHer(at: TestClock.now))
    }

    @Test("Rows are ordered by their most urgent reason, then by the earliest due date")
    func ordering() {
        let glow = makeService(followUpWeeks: 4)
        let ana = reachable("Ana Costa")
        let bea = reachable("Beatriz Lima")
        let cris = reachable("Cristina Alves", birthday: Birthday(month: 10, day: 3))
        let result = queue(
            [completed(ana, glow, daysAgo: 35), completed(bea, glow, daysAgo: 50)], clients: [ana, bea, cris],
            services: [glow]
        )
        #expect(result.rows.map(\.client.id) == [bea.id, ana.id, cris.id])
    }

    @Test("A client who asked not to be messaged is never suggested")
    func optedOut() {
        let glow = makeService(followUpWeeks: 4)
        let ana = Client(name: "Ana Costa", phoneE164: "+5511955550001", remindersEnabled: false,
                         createdAt: TestClock.days(-300))
        #expect(queue([completed(ana, glow, daysAgo: 90)], clients: [ana], services: [glow]).isEmpty)
    }
}
