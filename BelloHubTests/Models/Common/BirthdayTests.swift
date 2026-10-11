//
//  BirthdayTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Birthday and PersistedEnum")
struct BirthdayTests {
    @Test("Impossible dates are rejected, 29 February is allowed")
    func validation() {
        #expect(Birthday(month: 2, day: 30) == nil)
        #expect(Birthday(month: 4, day: 31) == nil)
        #expect(Birthday(month: 13, day: 1) == nil)
        #expect(Birthday(month: 0, day: 1) == nil)
        #expect(Birthday(month: 2, day: 29) != nil)
        #expect(Birthday(month: 12, day: 31, year: 1990) != nil)
    }

    @Test("The next occurrence is this year if it has not passed and next year if it has")
    func nextOccurrence() throws {
        let calendar = TestClock.calendar()
        let october = try #require(Birthday(month: 10, day: 5))
        let august = try #require(Birthday(month: 8, day: 3))

        #expect(october.nextOccurrence(onOrAfter: TestClock.now, calendar: calendar)
            == TestClock.date("2026-10-05 00:00"))
        #expect(august.nextOccurrence(onOrAfter: TestClock.now, calendar: calendar)
            == TestClock.date("2027-08-03 00:00"))
    }

    @Test("A birthday today counts as today")
    func today() throws {
        let birthday = try #require(Birthday(month: 10, day: 1))

        #expect(birthday.nextOccurrence(onOrAfter: TestClock.now, calendar: TestClock.calendar())
            == TestClock.date("2026-10-01 00:00"))
    }

    @Test("A 29 February birthday falls on the 28th in a year that is not a leap year")
    func leapDay() throws {
        let leap = try #require(Birthday(month: 2, day: 29))
        let calendar = TestClock.calendar()

        #expect(leap.nextOccurrence(onOrAfter: TestClock.date("2026-02-01 10:00"), calendar: calendar)
            == TestClock.date("2026-02-28 00:00"))
        #expect(leap.nextOccurrence(onOrAfter: TestClock.date("2027-12-01 10:00"), calendar: calendar)
            == TestClock.date("2028-02-29 00:00"))
    }

    // MARK: - PersistedEnum

    @Test("A raw value from a newer version falls back instead of crashing")
    func unknownRawValue() {
        #expect(AppointmentStatus(persisted: "rescheduledByRobot") == .booked)
        #expect(ClientSource(persisted: "telepathy") == .manual)
        #expect(PriceDisplay(persisted: "from-the-future") == .hide)
    }

    @Test("Fallbacks never make data more visible or blame a client")
    func safeFallbacks() {
        #expect(PhotoVisibility(persisted: "publicBillboard") == .professionalOnly)
        #expect(CancelledBy(persisted: "someoneNew") == .professional)
        #expect(IncidentSeverity(persisted: "catastrophic") == .moderate)
        #expect(AfterWindowCancel(persisted: "x") == .message)
    }

    @Test("Known values round-trip and unknown ones decode to the fallback")
    func codable() throws {
        let encoded = try JSONEncoder().encode(["status": AppointmentStatus.noShow])
        let decoded = try JSONDecoder().decode([String: AppointmentStatus].self, from: encoded)
        let newer = Data(#"{"status":"vanished"}"#.utf8)
        let future = try JSONDecoder().decode([String: AppointmentStatus].self, from: newer)

        #expect(decoded["status"] == .noShow)
        #expect(String(bytes: encoded, encoding: .utf8) == #"{"status":"noShow"}"#)
        #expect(future["status"] == .booked)
    }

    @Test("Every persisted enum round-trips all of its cases", arguments: [
        AppointmentStatus.allCases.map(\.rawValue), VisitType.allCases.map(\.rawValue),
        RecordResult.allCases.map(\.rawValue), PhotoKind.allCases.map(\.rawValue), NoShowAction.allCases.map(\.rawValue)
    ])
    func casesAreStable(rawValues: [String]) {
        #expect(Set(rawValues).count == rawValues.count)
        #expect(rawValues.allSatisfy { !$0.isEmpty })
    }
}
