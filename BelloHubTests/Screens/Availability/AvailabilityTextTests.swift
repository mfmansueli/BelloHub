//
//  AvailabilityTextTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AvailabilityText")
struct AvailabilityTextTests {
    private func formatters(_ localeID: String) -> Formatters {
        Formatters(locale: Locale(identifier: localeID), timeZone: TestClock.saoPaulo, currencyCode: "BRL")
    }

    private func text(_ localeID: String = "en_US", firstWeekday: Int = 1) -> AvailabilityText {
        AvailabilityText(formatters: formatters(localeID), firstWeekday: firstWeekday)
    }

    private let maria = makeAvailability()

    // MARK: - Runs and common hours

    @Test("Open days are grouped into runs in the order of the week")
    func runs() {
        #expect(AvailabilitySummary.openRuns(in: maria, firstWeekday: 1) == [[3, 4, 5, 6, 7]])
        let mondayToFriday = makeAvailability(weekdays: [2, 3, 4, 5, 6])
        #expect(AvailabilitySummary.openRuns(in: mondayToFriday, firstWeekday: 2) == [[2, 3, 4, 5, 6]])
        #expect(AvailabilitySummary.openRuns(in: mondayToFriday, firstWeekday: 1) == [[2, 3, 4, 5, 6]])
        let split = makeAvailability(weekdays: [1, 2, 4, 5, 7])
        #expect(AvailabilitySummary.openRuns(in: split, firstWeekday: 1) == [[1, 2], [4, 5], [7]])
        #expect(AvailabilitySummary.openRuns(in: split, firstWeekday: 2) == [[2], [4, 5], [7, 1]])
    }

    @Test("The hours are common only when every open day has the same single stretch")
    func commonHours() {
        #expect(AvailabilitySummary.commonHours(in: maria)?.start == 540)
        #expect(AvailabilitySummary.commonHours(in: maria)?.end == 1140)
        var varied = maria
        varied.weekly[0].endMinutes = 900
        #expect(AvailabilitySummary.commonHours(in: varied) == nil)
        var twice = maria
        twice.weekly.append(AvailabilityRule(weekday: 3, startMinutes: 1200, endMinutes: 1260))
        #expect(AvailabilitySummary.commonHours(in: twice) == nil)
        var none = maria
        none.weekly = []
        #expect(AvailabilitySummary.commonHours(in: none) == nil)
    }

    // MARK: - Words

    @Test("The week reads as Tue to Sat with the hours, in English")
    func weekSummaryEnglish() {
        let summary = text().weekSummary(of: maria)
        #expect(summary.hasPrefix("Tue to Sat · "), "\(summary)")
        #expect(summary.contains("9:00") && summary.contains("7:00"), "\(summary)")
    }

    @Test("The week summary follows the locale", arguments: [
        ("pt_BR", "ter. a sáb.", "09:00"), ("es_ES", "mar a sáb", "9:00"), ("de_DE", "Di bis Sa", "09:00"),
        ("fr_FR", "mar. à sam.", "09:00"), ("it_IT", "mar a sab", "09:00")
    ])
    func weekSummaryLocales(localeID: String, days: String, hour: String) {
        let summary = text(localeID).weekSummary(of: maria)
        #expect(summary.lowercased().contains(days.lowercased()), "\(localeID): \(summary)")
        #expect(summary.contains(hour), "\(localeID): \(summary)")
    }

    @Test("Days that do not follow each other are listed; one or two are named")
    func listedDays() {
        let split = makeAvailability(weekdays: [2, 3, 5])
        let summary = text().weekSummary(of: split)
        #expect(summary.hasPrefix("Mon and Tue and Thu") || summary.hasPrefix("Mon, Tue, and Thu")
            || summary.contains("Thu"), "\(summary)")
        #expect(!summary.contains(" to "), "two days and one day are named, not given as a range: \(summary)")
    }

    @Test("Hours that differ from day to day are left out of the summary")
    func differingHours() {
        var varied = maria
        varied.weekly[0].endMinutes = 900
        #expect(!text().weekSummary(of: varied).contains("·"))
    }

    @Test("No working hours says so")
    func none() {
        var closed = maria
        closed.weekly = []
        #expect(text().weekSummary(of: closed) == "No working hours yet")
    }

    @Test("A day's hours: one stretch, a split day as a list, and nil when closed")
    func dayHours() throws {
        #expect(text().hours(of: 1, in: maria) == nil)
        let one = try #require(text().hours(of: 3, in: maria))
        #expect(one.contains("9:00") && one.contains("7:00"), "\(one)")
        var split = maria
        split.weekly.removeAll { $0.weekday == 3 }
        split.weekly += [
            AvailabilityRule(weekday: 3, startMinutes: 540, endMinutes: 720),
            AvailabilityRule(weekday: 3, startMinutes: 840, endMinutes: 1080)
        ]
        let two = try #require(text().hours(of: 3, in: split))
        #expect(two.contains("12:00") && two.contains("2:00") && two.contains(" and "), "\(two)")
    }

    @Test("A break's detail names its time and the day or every day")
    func breakDetail() {
        let lunch = BreakRule(weekday: nil, startMinutes: 750, endMinutes: 810, label: "Lunch")
        #expect(text().detail(of: lunch).hasSuffix("· every day"))
        let monday = BreakRule(weekday: 2, startMinutes: 600, endMinutes: 615, label: "Coffee")
        #expect(text().detail(of: monday).hasSuffix("· Monday"))
        #expect(text("pt_BR").detail(of: monday).hasSuffix("segunda-feira"))
    }

    @Test("One day off reads as a date, several as a range")
    func dayOffRange() {
        let one = DayOff(id: UUID(), startDate: TestClock.date("2026-10-12 00:00"),
            endDate: TestClock.date("2026-10-12 00:00"), kind: .dayOff)
        #expect(text().range(of: one) == "Monday, October 12")
        let many = DayOff(id: UUID(), startDate: TestClock.date("2026-12-22 00:00"),
            endDate: TestClock.date("2027-01-05 00:00"), kind: .vacation)
        let range = text().range(of: many)
        #expect(range.contains("Dec") && range.contains("Jan") && range.contains("22") && range.contains("5"),
            "\(range)")
    }

    @Test("Times of day come back from minutes and into minutes in the business zone")
    func timesOfDay() {
        let formatters = formatters("en_US")
        for minutes in [0, 5, 540, 750, 1439] {
            #expect(formatters.minutesOfDay(formatters.timeOfDay(minutes: minutes)) == minutes)
        }
        #expect(formatters.time(minutes: 540).replacingOccurrences(of: "\u{202F}", with: " ") == "9:00 AM")
        #expect(formatters.time(minutes: 540, use24Hour: true) == "09:00")
        #expect(self.formatters("pt_BR").time(minutes: 1140) == "19:00")
    }

    @Test("Weekday names and hours are in the locale")
    func names() {
        #expect(formatters("en_US").weekdayName(3) == "Tuesday")
        #expect(formatters("en_US").weekdayShortName(1) == "Sun")
        #expect(formatters("pt_BR").weekdayName(2) == "segunda-feira")
        #expect(formatters("en_US").weekdayName(9).isEmpty)
        #expect(formatters("en_US").hours(24) == "24 hr")
    }
}
