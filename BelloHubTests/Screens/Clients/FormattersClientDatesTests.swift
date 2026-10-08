//
//  FormattersClientDatesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Formatters client dates")
struct FormattersClientDatesTests {
    private func formatters(_ locale: String = "en_US", zone: String = "America/Sao_Paulo") -> Formatters {
        Formatters(
            locale: Locale(identifier: locale), timeZone: TimeZone(identifier: zone) ?? .gmt, currencyCode: "BRL"
        )
    }

    @Test("A date in this year has no year: Aug 30")
    func thisYear() {
        let text = formatters().recentDate(TestClock.date("2026-08-30 15:00"), now: TestClock.now)

        #expect(text == "Aug 30")
    }

    @Test("A date in another year keeps its year, so an old visit is not mistaken for a recent one")
    func otherYear() {
        let text = formatters().recentDate(TestClock.date("2025-08-30 15:00"), now: TestClock.now)

        #expect(text == "Aug 30, 2025")
    }

    @Test("The day is the business day: 23:30 in São Paulo is still that day, not the next one in UTC")
    func businessTimeZone() {
        let lateEvening = TestClock.date("2026-08-30 23:30")

        #expect(formatters().recentDate(lateEvening, now: TestClock.now) == "Aug 30")
        #expect(formatters(zone: "Pacific/Auckland").recentDate(lateEvening, now: TestClock.now) == "Aug 31")
    }

    @Test("The same date reads in the locale's own order")
    func locales() {
        let date = TestClock.date("2026-08-30 15:00")

        #expect(formatters("pt_BR").recentDate(date, now: TestClock.now).hasPrefix("30"))
        #expect(formatters("en_US").recentDate(date, now: TestClock.now).hasPrefix("Aug"))
        #expect(formatters("de_DE").recentDate(date, now: TestClock.now).hasPrefix("30"))
    }

    @Test("Today and tomorrow are words, any other day is a date, and the time follows")
    func dayAndTime() {
        let english = formatters()
        func text(_ day: String) -> String {
            // Recent systems put a narrow no-break space before AM and PM; the test reads it as a plain space.
            english.dayAndTime(TestClock.date(day), now: TestClock.now, today: "Today", tomorrow: "Tomorrow")
                .replacingOccurrences(of: "\u{202F}", with: " ")
        }

        #expect(text("2026-10-01 15:00") == "Today · 3:00 PM")
        #expect(text("2026-10-02 09:30") == "Tomorrow · 9:30 AM")
        #expect(text("2026-10-05 09:30") == "Oct 5 · 9:30 AM")
    }
}
