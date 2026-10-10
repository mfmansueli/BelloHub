//
//  WaitlistMatcherTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("WaitlistMatcher")
struct WaitlistMatcherTests {
    private let calendar = TestClock.calendar()
    private let glow = makeService(name: "Glow Facial", minutes: 60)
    private let brazilian = makeService(name: "Brazilian Glow", minutes: 90)
    /// Helena's cancelled slot: Thursday Oct 15, 15:00 to 16:30.
    private var freed: DateInterval {
        DateInterval(start: TestClock.date("2026-10-15 15:00"), end: TestClock.date("2026-10-15 16:30"))
    }

    private func entry(
        _ name: String, service: UUID? = nil, from: String = "2026-10-12", to: String = "2026-10-18",
        status: WaitlistStatus = .waiting, createdDaysAgo: Int
    ) -> WaitlistEntry {
        WaitlistEntry(
            id: UUID(), clientID: nil, nameIfNoClient: name, phoneE164: "+5511999990000", serviceID: service,
            dayFrom: TestClock.date("\(from) 00:00"), dayTo: TestClock.date("\(to) 00:00"), status: status,
            createdAt: TestClock.days(-createdDaysAgo), offeredAt: nil
        )
    }

    private func names(_ entries: [WaitlistEntry], _ result: [WaitlistEntry]) -> [String] {
        result.map(\.nameIfNoClient)
    }

    @Test("First come, first served: Paula, Marina, Beatriz in the order they asked")
    func firstComeFirstServed() {
        let waiting = [entry("Beatriz", createdDaysAgo: 1), entry("Paula", createdDaysAgo: 9),
                       entry("Marina", createdDaysAgo: 4)]
        let result = WaitlistMatcher.matches(for: freed, entries: waiting, serviceFits: [:], calendar: calendar)

        #expect(names(waiting, result) == ["Paula", "Marina", "Beatriz"])
    }

    @Test("Only people still waiting, and only for days that include the freed day")
    func statusAndDays() {
        let waiting = [
            entry("Offered", status: .offered, createdDaysAgo: 5),
            entry("Booked", status: .booked, createdDaysAgo: 5),
            entry("Too early", from: "2026-10-01", to: "2026-10-14", createdDaysAgo: 5),
            entry("Too late", from: "2026-10-16", to: "2026-10-20", createdDaysAgo: 5),
            entry("On the day", from: "2026-10-15", to: "2026-10-15", createdDaysAgo: 5),
            entry("Open", createdDaysAgo: 5)
        ]
        let result = WaitlistMatcher.matches(for: freed, entries: waiting, serviceFits: [:], calendar: calendar)

        #expect(Set(names(waiting, result)) == ["On the day", "Open"])
    }

    @Test("A service with no free start in the freed time is left out; one that has, or that is not given, stays")
    func serviceFits() {
        let waiting = [
            entry("Fits", service: glow.id, createdDaysAgo: 3),
            entry("Too long", service: brazilian.id, createdDaysAgo: 2),
            entry("Anything", createdDaysAgo: 1),
            entry("Removed service", service: UUID(), createdDaysAgo: 4)
        ]
        let fits = [glow.id: true, brazilian.id: false]
        let result = WaitlistMatcher.matches(for: freed, entries: waiting, serviceFits: fits, calendar: calendar)

        #expect(Set(names(waiting, result)) == ["Fits", "Anything", "Removed service"])
    }

    @Test("A free start uses the freed time when its blocked stretch, extra time included, overlaps it")
    func usesFreedTime() {
        let before = TestClock.date("2026-10-15 13:45")
        let after = TestClock.date("2026-10-15 16:30")
        #expect(!WaitlistMatcher.usesFreedTime(freed, starts: [before], minutes: 60, timing: .noExtraTime))
        #expect(WaitlistMatcher.usesFreedTime(freed, starts: [before], minutes: 60,
                                              timing: VisitTiming(cleanupMinutes: 20)))
        #expect(!WaitlistMatcher.usesFreedTime(freed, starts: [after], minutes: 60, timing: .noExtraTime))
        #expect(WaitlistMatcher.usesFreedTime(freed, starts: [after], minutes: 60, timing: VisitTiming(prepMinutes: 5)))
    }

    @Test("Nobody waiting means no match")
    func empty() {
        #expect(WaitlistMatcher.matches(for: freed, entries: [], serviceFits: [:], calendar: calendar).isEmpty)
    }
}
