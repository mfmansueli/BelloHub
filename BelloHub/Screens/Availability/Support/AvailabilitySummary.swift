//
//  AvailabilitySummary.swift
//  BelloHub
//

import Foundation

/// The shape of her week in one line ("Tue to Sat · 09:00 to 19:00"), without any wording: which days are open in
/// runs, and the hours when every open day keeps the same ones. `AvailabilityText` turns it into words.
enum AvailabilitySummary {
    /// Open weekdays grouped into runs of days that follow each other in the week as drawn from `firstWeekday`.
    static func openRuns(in settings: AvailabilitySettings, firstWeekday: Int) -> [[Int]] {
        var runs: [[Int]] = []
        for weekday in AvailabilityEditor.weekdays(firstWeekday: firstWeekday)
        where AvailabilityEditor.isOpen(weekday, in: settings) {
            if let last = runs.last?.last, last % 7 + 1 == weekday {
                runs[runs.count - 1].append(weekday)
            } else {
                runs.append([weekday])
            }
        }
        return runs
    }

    /// The hours every open day shares, or nil when days differ or a day has more than one stretch.
    static func commonHours(in settings: AvailabilitySettings) -> (start: Int, end: Int)? {
        guard let first = settings.weekly.first else { return nil }
        let allSame = settings.weekly.allSatisfy {
            $0.startMinutes == first.startMinutes && $0.endMinutes == first.endMinutes
        }
        let singles = Set(settings.weekly.map(\.weekday)).count == settings.weekly.count
        return allSame && singles ? (first.startMinutes, first.endMinutes) : nil
    }
}
