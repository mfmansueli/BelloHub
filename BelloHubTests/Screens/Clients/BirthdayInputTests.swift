//
//  BirthdayInputTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BirthdayInput")
struct BirthdayInputTests {
    private func resolve(_ input: BirthdayInput, year: Int = 2026) -> Result<Birthday?, BirthdayInput.Problem> {
        input.resolve(currentYear: year)
    }

    @Test("Nothing picked is no birthday, not a problem")
    func empty() {
        #expect(resolve(BirthdayInput()) == .success(nil))
        #expect(BirthdayInput().isEmpty)
    }

    @Test("A day and a month are enough; the year is optional")
    func withoutYear() {
        #expect(resolve(BirthdayInput(day: 14, month: 3)) == .success(Birthday(month: 3, day: 14)))
        let withYear = BirthdayInput(day: 14, month: 3, year: 1990)

        #expect(resolve(withYear) == .success(Birthday(month: 3, day: 14, year: 1990)))
    }

    @Test("A day without a month, a month without a day, or a year alone is incomplete")
    func incomplete() {
        #expect(resolve(BirthdayInput(day: 14)) == .failure(.incomplete))
        #expect(resolve(BirthdayInput(month: 3)) == .failure(.incomplete))
        #expect(resolve(BirthdayInput(year: 1990)) == .failure(.incomplete))
    }

    @Test("A date that does not exist is refused")
    func invalidDates() {
        #expect(resolve(BirthdayInput(day: 31, month: 4)) == .failure(.invalidDate))
        #expect(resolve(BirthdayInput(day: 30, month: 2)) == .failure(.invalidDate))
    }

    @Test("29 February is allowed without a year, and with a year only in a leap year")
    func leapDay() {
        #expect(resolve(BirthdayInput(day: 29, month: 2)) == .success(Birthday(month: 2, day: 29)))
        let leapYear = BirthdayInput(day: 29, month: 2, year: 2000)
        #expect(resolve(leapYear) == .success(Birthday(month: 2, day: 29, year: 2000)))
        #expect(resolve(BirthdayInput(day: 29, month: 2, year: 1900)) == .failure(.invalidDate))
        #expect(resolve(BirthdayInput(day: 29, month: 2, year: 2001)) == .failure(.invalidDate))
    }

    @Test("The year has to be between 1900 and this year")
    func yearRange() {
        #expect(resolve(BirthdayInput(day: 1, month: 1, year: 1899)) == .failure(.invalidYear))
        #expect(resolve(BirthdayInput(day: 1, month: 1, year: 1900)) != .failure(.invalidYear))
        #expect(resolve(BirthdayInput(day: 1, month: 1, year: 2026)) != .failure(.invalidYear))
        #expect(resolve(BirthdayInput(day: 1, month: 1, year: 2027)) == .failure(.invalidYear))
    }

    @Test("A stored birthday round-trips through the input")
    func roundTrip() {
        let birthday = Birthday(month: 11, day: 2, year: 1985)

        #expect(resolve(BirthdayInput(birthday)) == .success(birthday))
        #expect(BirthdayInput(nil).isEmpty)
    }

    @Test("The year menu lists years newest first, and survives a year that is not in the Gregorian count")
    func yearOptions() {
        let years = BirthdayInput.yearOptions(currentYear: 2026)

        #expect(years.first == 2026 && years.last == 1900 && years.count == 127)
        #expect(BirthdayInput.yearOptions(currentYear: 1448) == [1900], "an Islamic year never inverts the range")
    }
}
