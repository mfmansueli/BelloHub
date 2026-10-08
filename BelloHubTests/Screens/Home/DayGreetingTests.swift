//
//  DayGreetingTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("DayGreeting")
struct DayGreetingTests {
    @Test("The greeting follows the hour in her time zone", arguments: [
        ("2026-10-01 04:59", DayGreeting.evening), ("2026-10-01 05:00", .morning), ("2026-10-01 11:59", .morning),
        ("2026-10-01 12:00", .afternoon), ("2026-10-01 17:59", .afternoon), ("2026-10-01 18:00", .evening),
        ("2026-10-01 23:59", .evening), ("2026-10-02 00:00", .evening)
    ])
    func hours(local: String, expected: DayGreeting) {
        let moment = TestClock.date(local)
        #expect(DayGreeting.at(moment, calendar: TestClock.calendar()) == expected)
    }

    @Test("The same instant is a different greeting in another time zone")
    func timeZone() {
        let moment = TestClock.date("2026-10-01 09:00")  // 09:00 in São Paulo, 13:00 in Lisbon
        #expect(DayGreeting.at(moment, calendar: TestClock.calendar("America/Sao_Paulo")) == .morning)
        #expect(DayGreeting.at(moment, calendar: TestClock.calendar("Europe/Lisbon")) == .afternoon)
    }
}
