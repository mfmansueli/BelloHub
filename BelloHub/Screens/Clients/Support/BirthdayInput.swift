//
//  BirthdayInput.swift
//  BelloHub
//

import Foundation

/// A birthday as the edit form holds it: three optional pieces she picks one by one. Day and month go together, the
/// year is optional (a client who does not share her year still has a birthday). Pure.
struct BirthdayInput: Equatable, Sendable {
    var day: Int?
    var month: Int?
    var year: Int?

    /// Years before this are not offered and not accepted.
    static let earliestYear = 1900

    enum Problem: Error, Equatable, Sendable {
        /// A day without a month, a month without a day, or a year alone.
        case incomplete
        /// 31 April, or 29 February of a year that is not a leap year.
        case invalidDate
        case invalidYear
    }

    /// The years the year menu offers, newest first. Never empty and never inverted, whatever year it is told.
    static func yearOptions(currentYear: Int) -> [Int] {
        Array((earliestYear...max(currentYear, earliestYear)).reversed())
    }

    init(day: Int? = nil, month: Int? = nil, year: Int? = nil) {
        self.day = day
        self.month = month
        self.year = year
    }

    init(_ birthday: Birthday?) {
        self.init(day: birthday?.day, month: birthday?.month, year: birthday?.year)
    }

    var isEmpty: Bool { day == nil && month == nil && year == nil }

    /// The birthday, nil when she picked nothing, or the reason it is not complete.
    func resolve(currentYear: Int) -> Result<Birthday?, Problem> {
        if isEmpty { return .success(nil) }
        guard let day, let month else { return .failure(.incomplete) }
        if let year {
            guard (Self.earliestYear...currentYear).contains(year) else { return .failure(.invalidYear) }
            if month == 2, day == 29, !Self.isLeapYear(year) { return .failure(.invalidDate) }
        }
        guard let birthday = Birthday(month: month, day: day, year: year) else { return .failure(.invalidDate) }
        return .success(birthday)
    }

    private static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }
}
