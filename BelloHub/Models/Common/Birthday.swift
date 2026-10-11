//
//  Birthday.swift
//  BelloHub
//

import Foundation

/// A day and month, with the year when she told us. Not a `Date`: a birthday has no time zone, and a client
/// who does not share her year still has a birthday.
struct Birthday: Hashable, Codable, Sendable {
    let month: Int
    let day: Int
    let year: Int?

    init?(month: Int, day: Int, year: Int? = nil) {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        // February 29 is allowed: a leap-day birthday is celebrated on the 28th in other years.
        let longest = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
        guard day <= longest else { return nil }
        self.month = month
        self.day = day
        self.year = year
    }

    /// The next time this birthday falls on or after `date`, in `calendar`'s time zone. 29 February falls on
    /// the 28th in a year that is not a leap year.
    func nextOccurrence(onOrAfter date: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: date)
        let thisYear = calendar.component(.year, from: today)
        for year in [thisYear, thisYear + 1] {
            if let candidate = occurrence(in: year, calendar: calendar), candidate >= today { return candidate }
        }
        return nil
    }

    private func occurrence(in year: Int, calendar: Calendar) -> Date? {
        var components = DateComponents(year: year, month: month, day: day)
        if let exact = calendar.date(from: components), calendar.component(.month, from: exact) == month {
            return exact
        }
        components.day = 28
        return calendar.date(from: components)
    }
}
