//
//  NextSessionRules.swift
//  BelloHub
//

import Foundation

/// When to suggest the next visit (5.9): the service's own follow-up interval when she set one, four weeks
/// otherwise, counted from the visit. A date that already passed (she is documenting an old visit) counts from today.
enum NextSessionRules {
    static let fallbackWeeks = 4
    static let weekChoices = [1, 2, 3, 4, 6, 8, 12]

    static func suggestedWeeks(serviceFollowUpWeeks: Int?) -> Int {
        guard let weeks = serviceFollowUpWeeks, weeks > 0 else { return fallbackWeeks }
        return weeks
    }

    /// The choices to show: the usual ones, plus the service's own interval when it is not among them.
    static func choices(including weeks: Int) -> [Int] {
        weekChoices.contains(weeks) ? weekChoices : (weekChoices + [weeks]).sorted()
    }

    static func date(afterVisit visit: Date, weeks: Int, now: Date, calendar: Calendar) -> Date {
        let counted = calendar.date(byAdding: .weekOfYear, value: weeks, to: visit) ?? visit
        if counted >= now { return counted }
        return calendar.date(byAdding: .weekOfYear, value: weeks, to: now) ?? now
    }
}
