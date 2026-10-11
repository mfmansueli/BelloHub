//
//  NextSessionRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("NextSessionRules")
struct NextSessionRulesTests {
    private let calendar = TestClock.calendar()

    @Test("The service's interval is used when it has one, four weeks otherwise")
    func suggestedWeeks() {
        #expect(NextSessionRules.suggestedWeeks(serviceFollowUpWeeks: 6) == 6)
        #expect(NextSessionRules.suggestedWeeks(serviceFollowUpWeeks: nil) == 4)
        #expect(NextSessionRules.suggestedWeeks(serviceFollowUpWeeks: 0) == 4)
    }

    @Test("An unusual interval is added to the usual choices, in order")
    func choicesIncludeTheDefault() {
        #expect(NextSessionRules.choices(including: 5) == [1, 2, 3, 4, 5, 6, 8, 12])
        #expect(NextSessionRules.choices(including: 4) == NextSessionRules.weekChoices)
    }

    @Test("The date counts from the visit")
    func countsFromTheVisit() {
        let visit = TestClock.days(-1)
        let date = NextSessionRules.date(afterVisit: visit, weeks: 4, now: TestClock.now, calendar: calendar)
        #expect(date == calendar.date(byAdding: .weekOfYear, value: 4, to: visit))
    }

    @Test("A visit long past counts from today, so the suggestion is never in the past")
    func oldVisitCountsFromToday() {
        let visit = TestClock.days(-90)
        let date = NextSessionRules.date(afterVisit: visit, weeks: 4, now: TestClock.now, calendar: calendar)
        #expect(date == calendar.date(byAdding: .weekOfYear, value: 4, to: TestClock.now))
    }
}
